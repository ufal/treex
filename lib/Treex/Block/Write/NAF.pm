package Treex::Block::Write::NAF;

use Moose;
use Treex::Core::Common;
use String::Util qw(trim);

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.NAF' );

my %blocks = (
  raw => "",
  text => "",
  terms => "",
  entities => "",
  markables => "",
  deps => "",
  coreferences =>""
);

my $sentenceNum = 0;
my $corefNum = 0;

override 'print_header' => sub {
    my ($self, $doc) = @_;
    print {$self->_file_handle} '<?xml version=\'1.0\' encoding=\'UTF-8\'?>
<NAF version="1.0" xml:lang="cs">
  <nafHeader>
    <linguisticProcessors layer="text">
      <lp beginTimestamp="2014-09-30T01:22:13+0200" endTimestamp="2014-09-30T01:22:14+0200" name="ufal-treex-pipe-tok-cs" version="1.5.1" />
    </linguisticProcessors>
    <linguisticProcessors layer="terms">
      <lp beginTimestamp="2014-09-30T01:22:17+0200" endTimestamp="2014-09-30T01:22:18+0200" name="ufal-treex-pipe-pos-cs" version="1.2.0" />
    </linguisticProcessors>
    <linguisticProcessors layer="entities">
      <lp beginTimestamp="2014-09-30T01:22:21+0200" endTimestamp="2014-09-30T01:22:40+0200" name="ufal-treex-pipe-nerc-cs" version="1.1.4" />
    </linguisticProcessors>
    <linguisticProcessors layer="deps">
      <lp beginTimestamp="2014-09-30T01:23:24+0200" endTimestamp="2014-09-30T01:24:28+0200" name="ufal-treex-pipe-deps-cs" version="1.0" />
    </linguisticProcessors>
    <linguisticProcessors layer="coreferences">
      <lp name="ufal-treex-pipe-corefgraph-cs" timestamp="2014-09-30T01:29:03" version="1.0" />
    </linguisticProcessors>
  </nafHeader>' . "\n";
};
override 'print_footer' => sub {
    my ($self, $doc) = @_;
    my @blockOrder = ('raw', 'text', 'terms', 'entities', 'deps', 'coreferences');
    foreach my $blockname (@blockOrder){
      print {$self->_file_handle} "<$blockname" . ($blockname ne "markables" ? "" : ' source="DBpedia"') . ">\n", $blocks{$blockname}, "<\/$blockname>\n";
    }    
    print {$self->_file_handle} "</NAF>";
};

sub escape_xml {
    my ($self, $string) = @_;
    return if !defined $string;
    $string =~ s/&/&amp;/g;
    $string =~ s/</&lt;/g;
    $string =~ s/>/&gt;/g;
    $string =~ s/'/&apos;/g;
    $string =~ s/"/&quot;/g;
    return $string;
}

sub _guess_conll_label {
  my ($self, $label ) = @_;
  
  my %CONLL_LABELS = ( 'PERSON' => 1, 'LOCATION' => 1, 'ORGANISATION' => 1, 'MISC' => 1, 'O' => 1 );
  
  return $label if exists $CONLL_LABELS{$label};
  # TODO: My first guess about transforming fine-grained 2-character Czech NE
  # labels to CoNLL2003 labels.
  return 'MISC' if $label =~ /^[acnoqt]/;
  return 'PERSON' if $label =~ /^p/;
  return 'LOCATION' if $label =~ /^g/;
  return 'ORGANISATION' if $label =~ /^[im]/;
}


sub process_zone {
    my ($self, $zone) = @_;
    $sentenceNum++;
    my $currentOffset = length($blocks{'raw'});
    #my $zone = $bundle->get_zone($self->language);
    $blocks{'raw'} .= $zone->sentence . "\n\n";
    my $ttree = $zone->get_ttree();
    my @tnodes = $ttree->get_descendants({ordered => 1});
    foreach my $tnode (@tnodes){
      #Vallex
      my $lanode = $tnode->get_lex_anode();
      if ($lanode){
        if (defined $tnode->{'val_frame.rf'} && $tnode->{'val_frame.rf'} ne ""){
          $lanode->wild->{'vallex'} = $tnode->{'val_frame.rf'};
        }
        my @coref_ids = ($lanode->id);
        #coref_text
        my @coref_text_tnodes = $tnode->get_coref_text_nodes();
        if (scalar @coref_text_tnodes > 0){
          foreach my $coref_text_tnode (@coref_text_tnodes){
            my $coref_text_lanode = $coref_text_tnode->get_lex_anode();
            if ($coref_text_lanode){
              push(@coref_ids, $coref_text_lanode->id);
            }
          }
        }
        #coref_gram
        my @coref_gram_tnodes = $tnode->get_coref_gram_nodes();
        if (scalar @coref_gram_tnodes > 0){
          foreach my $coref_gram_tnode (@coref_gram_tnodes){
            my $coref_gram_lanode = $coref_gram_tnode->get_lex_anode();
            if ($coref_gram_lanode){
              push(@coref_ids, $coref_gram_lanode->id);
            }
          }
        }
        if (scalar @coref_ids > 1){
          $corefNum++;
          $blocks{'coreferences'} .= '<coref id="co' . $corefNum . '">' . "\n";
          foreach my $coref_id (@coref_ids){
                      $blocks{'coreferences'} .= '<span>
    <target id="' . $coref_id . '" />
  </span>
';
          }
          $blocks{'coreferences'} .= '</coref>' . "\n";
        }
      }
    }
    
    
    my $atree = $zone->get_atree();
    my @anodes = $atree->get_descendants({ordered => 1});
    foreach my $anode (@anodes){
      $blocks{'text'} .= '<wf id="w' . $anode->id . '" length="' . length($anode->form) . '" offset="' . $currentOffset . '" para="' . $sentenceNum . '" sent="' . $sentenceNum . '">' . $self->escape_xml($anode->form) . '</wf>' . "\n";
      $currentOffset += length($anode->form);
      if ($anode->no_space_after == 0){
        $currentOffset++;
      }
      $blocks{'terms'} .= '<term id="' . $anode->id . '" lemma="' . $self->escape_xml($anode->lemma) . '" morphofeat="' . $anode->tag . '" pos="' . substr($anode->tag, 0, 1) . '" type="' . (defined $anode->wild->{'vallex'} && $anode->wild->{'vallex'} ne "" ? "open" : "close") . '">
      <span>
        <target id="w' . $anode->id . '" />
      </span>' . (defined $anode->wild->{'vallex'} && $anode->wild->{'vallex'} ne "" ? '
      <externalReferences>
        <externalRef confidence="1" reference="' . $anode->wild->{'vallex'} . '" resource="Vallex.bin64" />
      </externalReferences>' : '') . '
    </term>
    ';
      #my $nnode = $anode->n_node();
      my $parent_node = $anode->get_parent();
      if (!$parent_node->is_root()){
        $blocks{'deps'} .= '<dep from="' . $parent_node->id . '" rfunc="' . $anode->afun . '" to="' . $anode->id . '" />' . "\n";
      }
      
    }
    
    my $ntree = $zone->get_ntree();
    foreach my $nnode ($ntree->get_descendants()){
      if (defined $nnode->wild->{'dbpedia_reference'} && $nnode->wild->{'dbpedia_reference'} ne ""){
        $blocks{'entities'} .= '<entity id="'. $nnode->id .'" type="' . $self->_guess_conll_label($nnode->ne_type) . '">
        <references>
        <span>
        ';
        foreach my $named_anode ($nnode->get_anodes()){
          $blocks{'entities'} .= '<target id="w' . $named_anode->id . '" />' . "\n";
        }
        my $reference = $nnode->wild->{'dbpedia_reference'};
        chomp($reference);
        $blocks{'entities'} .= '</span>
          </references>
          <externalReferences>
            <externalRef confidence="1.0" reference="' . $reference . '" resource="spotlight_v1" />
          </externalReferences>
        </entity>
        ';
      }

    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::NAF - writer for NLP Annotation Format

=head1 DESCRIPTION

For details about the format see

L<http://www.newsreader-project.eu/files/2013/01/techreport.pdf>

L<https://github.com/newsreader/NAF>


=head1 AUTHOR

Roman Sudarikov <sudarikov@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
