package Treex::Block::A2T::EN::MarkTextCoref;
use Moose;
use Treex::Core::Common;
use Lingua::StanfordCoreNLP;

has '_pipeline' => ( is => 'ro', isa => 'Lingua::StanfordCoreNLP::Pipeline', builder => '_build_pipeline');

sub _build_pipeline {
    my ($self) = @_;

    my $pipeline = Lingua::StanfordCoreNLP::Pipeline->new(0);
    my $props = $pipeline->getProperties();
    $props->put('annotators', 'tokenize, ssplit, pos, lemma, ner, parse, dcoref');
    $pipeline->setProperties($props);
    
    return $pipeline;
}

sub mention_descr_2_tnode {
    my ($all_nodes, $word_idx, $word) = @_;

    my $anode = $all_anodes->[$word_idx]; 
    if (!defined $anode || $anode->form ne $word) {
        # TODO debug print
        print STDERR Dumper(\@all)
    }
    my ($tnode) = ($anode->get_referencing_nodes('a/lex.rf'), $anode->get_referencing_nodes('a/aux.rf'));
    return $tnode;
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    # TODO test on documents consisting of independent segments (e.g. CzEng)
    my @zones = map {$_->get_zone($self->language, $self->selector)} $doc->get_bundles;
    my @sentences = map {$_->sentence} @zones;

    my $result = $self->_pipeline->process(join " ", @sentences);

    # collect coreference links and create a grid of mentions indexed by (sent_idx X word_idx) in order to process it sequentially
    my @coref_links = ();
    my %word_grid = ();
    for my $sentence (@{$result->toArray}) {
        for my $coref (@{$sentence->getCoreferences->toArray}) {
            my $coref_info = {
                src_sent => $coref->getSourceSentence,
                src_idx => $coref->getSourceHead,
                tgt_sent => $coref->getTargetSentence,
                tgt_idx => $coref->getTargetHead,
            };
            push @coref_links, $coref_info;
            $word_grid{$coref_info->{src_sent}}{$coref_info->{src_idx}} = $coref->getSourceToken->getWord;
            $word_grid{$coref_info->{tgt_sent}}{$coref_info->{tgt_idx}} = $coref->getTargetToken->getWord;
        }
    }

    # collect a tnode for every mention in the mention grid
    my %t_mentions = ();
    foreach my $sent_idx (keys %word_grid) {
        my $zone = $zones[$sent_idx];
        my $aroot = $zone->get_atree;
        my @all_anodes = $aroot->get_descendants({ordered=>1});
        foreach my $word_idx (keys %{$word_grid{$sent_idx}}) {
            $t_mentions{$sent_idx}{$word_idx} = mention_descr_2_tnode(\@all_anodes, $word_idx, $word_grid{$sent_idx}{$word_idx});
        }
    }

    # add links between tnodes
    foreach my $coref_info (@coref_links) {
        my $ante_tnode = $t_mentions{$coref_info->{src_sent}}{$coref_info->{src_idx}};
        my $anaph_tnode = $t_mentions{$coref_info->{tgt_sent}}{$coref_info->{tgt_idx}};
        $anaph_tnode->add_coref_text_node($ante_tnode);
    }
};

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::MarkTextPronCoref

=head1 DESCRIPTION

Pronoun coreference resolver for English.
Settings:
* English personal pronoun filtering of anaphor
* candidates for the antecedent are nouns from current (prior to anaphor) and previous sentence
* English pronoun coreference feature extractor
* using a model trained by a perceptron ranker

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
