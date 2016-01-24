package Parse;

use strict;
use warnings;
use utf8;
use Storable;

use Data::Dumper;
use XML::Twig;

my %all;

sub parseHTMLSH {
  my ($source, $silent) = @_;

  if(-r "$source.store") {
    my $law = retrieve("$source.store");
    $all{$law->{'name'} . '(' . $law->{'veryshorthand'} . ')'} = $law;

    print "Loaded " . $law->{'name'} . ' (' . $law->{'veryshorthand'} . ")\n" unless $silent;

    return;
  }

  print "Parsing $source...\n";

  open HTML, '<:utf8', $source or die "cannot open $source: $!";
  my $xml = XML::Twig->new();
  $xml->parse(join('', <HTML>));
  close HTML;


  my $content = $xml->root();
  my $veryshorthand = saneSpacing([$content->get_xpath('//table[@class="TableRahmenkpl"]//td[@class="TD70"]')]->[0]->text());
  my $name = [$content->get_xpath('//div[@class="docLayoutTitel"]')]->[0]->text();
  $name =~ s/^\s+Vom.*$//gm;
  $name = saneSpacing($name);

  my $shorthand = $veryshorthand;
  if($name =~ /\(([^)]+)\)/) {
    $shorthand = $1;
    $shorthand =~ s/ - .*//g;
    $shorthand = saneSpacing($shorthand);
  }

  print "$shorthand: $name\n";

  my @paragraphs;
  
  my @blocks = $content->get_xpath('//div[@class="docLayoutText"]//div[@class="docLayoutMarginTop"]');
  foreach my $block (@blocks) {
    my ($h3) = $block->get_xpath('h3');
    last if($h3 and saneSpacing($h3->text()) =~ /^Anlage( A)?:$/);

    my ($header) = $block->get_xpath('h3[@class="paranr"]');
    my ($headerTitle) = $block->get_xpath('h3[@class="paratitel"]');
    unless($header) {
      ($header) = $block->get_xpath('h4[@class="paranr"]');
      ($headerTitle) = $block->get_xpath('h4[@class="paratitel"]');
    }
    unless($header) {
      ($header) = $block->get_xpath('h5[@class="paranr"]');
      ($headerTitle) = $block->get_xpath('h5[@class="paratitel"]');
    }
    unless($header) {
      ($header) = $block->get_xpath('h6[@class="paranr"]');
      ($headerTitle) = $block->get_xpath('h6[@class="paratitel"]');
    }
    unless($header) {
      ($header) = $block->get_xpath('p[@class="paranr"]');
      ($headerTitle) = $block->get_xpath('p[@class="paratitel"]');
    }
    next unless $header;

    my $paragraphNumber = saneSpacing($header->text());
    my $paragraphTitle;
    if($headerTitle) {
      $paragraphTitle = saneSpacing($headerTitle->text());
    }

    if($paragraphNumber =~ /^§ ?(\d+)\s*(\S*)$/s) {
      my $trailing = $2;
      $trailing =~ s/\*\)//g;
      $trailing =~ s/\^\[?\d+\]?//g;
      my $paragraph = {
        'number' => "$1$trailing",
        'absatz' => [],
      };
      $paragraph->{'title'} = $paragraphTitle if($paragraphTitle);
      push @paragraphs, $paragraph;

      parseAbsatzSH($block, $paragraph);

      print "Parsed § " . $paragraph->{'number'} . ' ' . ($paragraph->{'title'}? $paragraph->{'title'}: "") . "\n" unless $silent;
    } elsif($paragraphNumber =~ /^(?:Art\.?|Artikel) (\S*)$/s) {
      my $paragraph = {
        'number' => "Artikel $1",
        'title' => $2,
        'absatz' => [],
      };
      push @paragraphs, $paragraph;

      parseAbsatz($block, $paragraph);

      print "Parsed " . $paragraph->{'number'} . ' ' . ($paragraph->{'title'}? $paragraph->{'title'}: "") . "\n" unless $silent;
    } elsif($paragraphNumber =~ /^([IVXLCDM]+)\.\s*(.*)$/s) {
      my $paragraph = {
        'number' => "Artikel $1",
        'title' => $2,
        'absatz' => [],
      };
      push @paragraphs, $paragraph;

      parseAbsatz($block, $paragraph);

      print "Parsed " . $paragraph->{'number'} . ' ' . ($paragraph->{'title'}? $paragraph->{'title'}: "") . "\n" unless $silent;
    } elsif($paragraphNumber =~ /^(?:Einziger )?Artikel$/s) {
      my $paragraph = {
        'number' => "Artikel 1",
        'absatz' => [],
      };
      push @paragraphs, $paragraph;

      parseAbsatz($block, $paragraph);

      print "Parsed " . $paragraph->{'number'} . ' ' . ($paragraph->{'title'}? $paragraph->{'title'}: "") . "\n" unless $silent;
    } elsif($paragraphNumber =~ /^§§? \d+ bis \d+(?:\*\))?$/s) {
      # skip
    } elsif($paragraphNumber =~ /^§§? \d+ - \d+(?:\*\))?$/s) {
      # skip
    } elsif($paragraphNumber =~ /^§§? \d+ u\. \d+(?:\*\))?$/s) {
      # skip
    } else {
      print $paragraphNumber;
      die;
    }
  }

  print "Parsed $name ($veryshorthand)\n" unless $silent;

  my $law = {
    'name' => $name,
    'shorthand' => $shorthand,
    'veryshorthand' => $veryshorthand,
    'paragraph' => \@paragraphs,
    'source' => $source,
  };

  store $law, "$source.store";
  $all{$law->{'name'} . '(' . $law->{'veryshorthand'} . ')'} = $law;
}

sub parseAbsatzSH {
  my ($block, $paragraph) = @_;

  my @absatz = $block->get_xpath('p');
  foreach my $absatz (@absatz) {
    my $text = $absatz->text();
    $text =~ s/\s+ / /g;

    if($text =~ /^\((\d+)\S*\) (.*)$/s) {
      $absatz = {
        'number' => $1,
        'text' => $2,
      };
    } else {
      $absatz = {
        'text' => $text,
      };
    }

    push @{$paragraph->{'absatz'}}, $absatz;
  }
}

sub parseHTML {
  my ($source, $silent) = @_;

  if(-r "$source.store") {
    my $law = retrieve("$source.store");
    $all{$law->{'name'} . '(' . $law->{'veryshorthand'} . ')'} = $law;

    print "Loaded " . $law->{'name'} . ' (' . $law->{'veryshorthand'} . ")\n" unless $silent;

    return;
  }

  print "Parsing $source...\n";

  open HTML, '<:encoding(iso-8859-1)', $source or die "cannot open $source: $!";
  my $xml = XML::Twig->new();
  $xml->parse(join('', <HTML>));
  close HTML;

  # die Dumper($xml);

  my $name;
  my $shorthand;
  my $veryshorthand;
  my @paragraphs;

  my $content = $xml->root();
  $content = $content->first_child('body');
  (undef, undef, $content) = $content->children('div');
  $content = $content->first_child('div');
  $content = $content->first_child('div');
  $content = $content->first_child('div');
  
  my @blocks = $content->children();
  my $h1;
  my $h2;

  foreach my $block (@blocks) {
    # $block->print();

    if($block->descendants('h1')) {
      $h1 = $block->first_descendant('h1');
      # $h1->print();

      if($name) {
        die "two title blocks found";
      }

      if($h1->text() =~ /(.*?)\s*\(([^)]*)\)/) {
        $name = $1;
        $shorthand = $2;
      } else {
        $name = $h1->text();
        $shorthand = $h1->next_sibling()->next_sibling()->text();
      }

      $veryshorthand = $h1->next_sibling()->next_sibling()->text();
    } elsif($block->descendants('h2')) {
      $h2 = $block->first_descendant('h2');

      # skip
    } elsif($block->descendants('h3')) {
      my $h3 = $block->first_descendant('h3');

      if($h3->text() =~ /^\s*Inhaltsübersicht\s*$/s) {
        # skip
      } elsif($h3->text() =~ /^\s*Inhaltsverzeichnis\s*$/s) {
        # skip
      } elsif($h3->text() =~ /^\s*Inhaltsverzeichnis\s*\*\)\s*$/s) {
        # skip
      } elsif($h3->text() =~ /^\s*Inhalt\s*$/s) {
        # skip
      } elsif($h3->text() =~ /^\s*Gliederung\s*$/s) {
        # skip
      } elsif($h3->text() =~ /^\s*Übersicht\s*$/s) {
        # skip
      } elsif($h3->text() =~ /^\s*Eingangsformel/s) {
        # skip
      } elsif($h3->text() =~ /^\s*Präambel/s) {
        # skip
      } elsif($h3->text() =~ /^\s*Anhang/s) {
        # skip
      } elsif($h3->text() =~ /^\s*\(?Anlage/s) {
        # skip
      } elsif($h3->text() =~ /^§ (\d+\S*)\s*(.*)$/s) {
        my $paragraph = {
          'number' => $1,
          'title' => $2,
          'absatz' => [],
        };
        push @paragraphs, $paragraph;

        parseAbsatz($block, $paragraph);

        print "Parsed § " . $paragraph->{'number'} . ' ' . $paragraph->{'title'} . "\n" unless $silent;
      } elsif($h3->text() =~ /^(?:Art\.?|Artikel) (\S*)\s*(.*)$/s) {
        my $paragraph = {
          'number' => "Artikel $1",
          'title' => $2,
          'absatz' => [],
        };
        push @paragraphs, $paragraph;

        parseAbsatz($block, $paragraph);

        print "Parsed " . $paragraph->{'number'} . ' ' . $paragraph->{'title'} . "\n" unless $silent;
      } elsif($h3->text() =~ /^(?:Nr\.?|Nummer) (\S*)\s*(.*)$/s) {
        my $paragraph = {
          'number' => "Nummer $1",
          'title' => $2,
          'absatz' => [],
        };
        push @paragraphs, $paragraph;

        parseAbsatz($block, $paragraph);

        print "Parsed " . $paragraph->{'number'} . ' ' . $paragraph->{'title'} . "\n" unless $silent;
      } elsif($h3->text() =~ /^(Tabelle|Formblatt|Muster|Regel) (\S*)\s*(.*)$/s) {
        my $paragraph = {
          'number' => "$1 $2",
          'title' => $3,
          'absatz' => [],
        };
        push @paragraphs, $paragraph;

        parseAbsatz($block, $paragraph);

        print "Parsed " . $paragraph->{'number'} . ' ' . $paragraph->{'title'} . "\n" unless $silent;
      } elsif($h3->text() =~ /^([IVXLCDM]+)\.\s*(.*)$/s) {
        my $paragraph = {
          'number' => "Artikel $1",
          'title' => $2,
          'absatz' => [],
        };
        push @paragraphs, $paragraph;

        parseAbsatz($block, $paragraph);

        print "Parsed " . $paragraph->{'number'} . ' ' . $paragraph->{'title'} . "\n" unless $silent;
      } elsif($h3->text() =~ /^([0-9A-Z][0-9A-Za-z]*)\.\s*(.*)$/s) {
        my $paragraph = {
          'number' => "Artikel $1",
          'title' => $2,
          'absatz' => [],
        };
        push @paragraphs, $paragraph;

        parseAbsatz($block, $paragraph);

        print "Parsed " . $paragraph->{'number'} . ' ' . $paragraph->{'title'} . "\n" unless $silent;
      } elsif($h3->text() =~ /^\s*(Registrierung von Verbänden und deren Vertreter|Befragung der Bundesregierung|Protokollnotiz .*|Protokoll.*|Gemeinsames Protokoll.*|Einziger Paragraph|Dienstanweisung.*)\s*$/s) {
        my $paragraph = {
          'number' => "$1",
          'title' => "$1",
          'absatz' => [],
        };
        push @paragraphs, $paragraph;

        parseAbsatz($block, $paragraph);

        print "Parsed " . $paragraph->{'number'} . ' ' . $paragraph->{'title'} . "\n" unless $silent;
      } elsif($h3->text() =~ /\(Änderungs- und Aufhebungsvorschriften\)/) {
        # skip
      } elsif($h3->text() =~ /weggefallen/) {
        # skip
      } elsif($h3->text() =~ /\(zukünftig in Kraft\)/) {
        # skip
      } elsif($h3->text() =~ /----/) {
        # skip
      } elsif($h3->text() =~ /\(gegenstandslos\)/) {
        # skip
      } elsif($h3->text() =~ /\(Änderung von Rechtsvorschriften, Überleitung von Verweisungen, Aufhebung von Vorschriften\)/) {
        # skip
      } elsif($h3->text() =~ /Schlu(ß|ss)formel/) {
        # skip
      } elsif($block->text() =~ /Inhalt: [Nn]icht darstellbar/) {
        # skip
      } elsif($block->text() =~ /\(weggefallen\)/) {
        # skip
      } elsif($block->text() =~ /\(Änderung anderer Vorschriften\)/) {
        # skip
      } elsif($h3->text() =~ /^Abbildung de/) {
        # skip
      } elsif($h3->text() =~ /^Wirtschaftsplan /) {
        # skip
      } elsif($h3->text() =~ /^Gesamtplan /) {
        # skip
      } elsif($h3->text() =~ /Nachtrag zum Gesamtplan des Bundeshaushaltsplans/) {
        # skip
      } elsif($block->descendants('img')) {
        # skip
      } elsif($h3->text() =~ /^Vorschriften für/) {
        # TODO
        # skip
      } elsif($h3->text() =~ /^§§ \d+ bis \d+/
          and $h2->text() =~ /weggefallen/) {
        # skip
      } else {
        $block->print();
        print "\n" . $h3->text() . "\n";
        print $name . "\n";
        die;
      }
    } else {
      $block->print();
      print $name . "\n";
      die;
    }
  }

  print "Parsed $name ($veryshorthand)\n" unless $silent;

  my $law = {
    'name' => $name,
    'shorthand' => $shorthand,
    'veryshorthand' => $veryshorthand,
    'paragraph' => \@paragraphs,
    'source' => $source,
  };

  store $law, "$source.store";
  $all{$law->{'name'} . '(' . $law->{'veryshorthand'} . ')'} = $law;
}

sub all {
  return \%all;
}

sub WTF {
  my ($block, $paragraph) = @_;

  my @absatz = $block->descendants('div[@class="jurAbsatz"]');
  foreach my $absatz (@absatz) {
    my $text = $absatz->inner_xml();
    print "$text\n";
  }
}

sub parseAbsatz {
  my ($block, $paragraph) = @_;

  my @absatz = $block->descendants('div[@class="jurAbsatz"]');
  foreach my $absatz (@absatz) {
    my $text = $absatz->inner_xml();
    $text =~ s/<[^>]*>/ /g;

    if($absatz->parent('div[@class="jnfussnote"]')) {
      next;
    }

    if($text =~ /^\((\d+)\S*\) (.*)$/s) {
      $absatz = {
        'number' => $1,
        'text' => $2,
      };
    } else {
      $absatz = {
        'text' => $text,
      };
    }

    push @{$paragraph->{'absatz'}}, $absatz;
  }
}

sub saneSpacing {
  my ($s) = @_;
  $s =~ s/\s+/ /g;
  $s =~ s/^\s+//g;
  $s =~ s/\s+$//g;
  return $s;
}

1;

#TODO kill text where "weggefallen" etc. is the only content
