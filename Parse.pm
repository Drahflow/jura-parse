package Parse;

use strict;
use warnings;
use encoding 'utf-8';
use Storable;

use Data::Dumper;
use XML::Twig;

my %all;

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

  foreach my $block (@blocks) {
    # $block->print();

    if($block->descendants('h1')) {
      my $h1 = $block->first_descendant('h1');
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
      my $h2 = $block->first_descendant('h2');

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
      } elsif($h3->text() =~ /^\s*Anlage/s) {
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
      } elsif($h3->text() =~ /\(weggefallen\)/) {
        # skip
      } elsif($h3->text() =~ /\(zukünftig in Kraft\)/) {
        # skip
      } elsif($h3->text() =~ /----/) {
        # skip
      } elsif($h3->text() =~ /\(gegenstandslos\)/) {
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
      } elsif($block->descendants('img')) {
        # skip
      } elsif($h3->text() =~ /^Vorschriften für/) {
        # TODO
        # skip
      } else {
        $block->print();
        die;
      }
    } else {
      $block->print();
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

1;

#TODO kill text where "weggefallen" etc. is the only content
