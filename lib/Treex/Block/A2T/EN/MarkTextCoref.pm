package Treex::Block::A2T::EN::MarkTextCoref;
use Moose;
use Treex::Core::Common;
use Lingua::StanfordCoreNLP;

extends 'Treex::Core::Block';

has '_pipeline' => ( is => 'ro', builder => '_build_pipeline');

sub _build_pipeline {
    my ($self) = @_;

    # must be here to access the inline class Lingua::StanfordCoreNLP::Pipeline
    Inline->init();
    my $pipeline = new Lingua::StanfordCoreNLP::Pipeline(0);
    my $props = $pipeline->getProperties();
    $props->put('annotators', 'tokenize, ssplit, pos, lemma, ner, parse, dcoref');
    $pipeline->setProperties($props);
    
    return $pipeline;
}

sub mention_descr_2_tnode {
    my ($all_anodes, $word_idx, $word) = @_;

    my $anode = $all_anodes->[$word_idx]; 
    #if (!defined $anode || $anode->form ne $word) {
        # TODO debug print
    #    my @forms = map {$_->form} @$all_anodes;
    #    print STDERR Dumper(\@forms, $word_idx, $word);
    #}
    my ($tnode) = ($anode->get_referencing_nodes('a/lex.rf'), $anode->get_referencing_nodes('a/aux.rf'));
    return $tnode;
}

sub align_arrays {
    my ($a1, $a2) = @_;

    my %align = ();

    my $i1 = 0; my $i2 = 0;
    my $j1 = 0; my $j2 = 0;
    my $l1 = length($a1->[$i1][$j1]);
    my $l2 = length($a2->[$i2][$j2]);
    $align{"$i1,$j1"} = "$i2,$j2";
    while ($i1 < @$a1 || $i2 < @$a2) {
        while ($j1 < @{$a1->[$i1]} && $j2 < @{$a2->[$i2]}) {
            if ($l1 < $l2) {
                $i1++;
                $l1 += length($a1->[$i1]);
            }
            elsif ($l2 < $l1) {
                $i2++;
                $l2 += length($a2->[$i2]);
            }
            else {
                $i1++; $i2++;
                $l1 += length($a1->[$i1]);
                $l2 += length($a2->[$i2]);
            }
            $align{"$i1,$j1"} = "$i2,$j2" if (!defined $align{"$i1,$j1"});
        }
        if ($j1 < @{$a1->[$i1]}) {
            $i2++; $j2 = 0;
        }
        if ($j2 < @{$a2->[$i2]}) {
            $i1++; $j1 = 0;
        }
    }

    return \%align;
}

sub process_document {
    my ($self, $doc) = @_;

    # TODO test on documents consisting of independent segments (e.g. CzEng)
    my @zones = map {$_->get_zone($self->language, $self->selector)} $doc->get_bundles;

    my $result = $self->_pipeline->process(join "\n", map {$_->sentence} @zones);
    
    # collect coreference links and create a grid of mentions indexed by (sent_idx X word_idx) in order to process it sequentially
    my @coref_links = ();
    my %word_grid = ();
    for my $sentence (@{$result->toArray}) {
        if ($doc->full_filename eq "data/dev.pcedt/wsj_2008") {
            print STDERR $sentence->getIDString . ": ". $sentence->getSentence . "\n";
        }
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

    my @our_tokens = map {[map {$_->form} $_->get_atree->get_descendants({ordered=>1})]} @zones;
    my @stanford_tokens = map {[map {$_->getWord} @{$_->getTokens->toArray}]} @{$result->toArray};
    my $token_align = align_arrays(\@stanford_tokens, \@our_tokens);


    # collect a tnode for every mention in the mention grid
    my %t_mentions = ();
    foreach my $sent_idx (keys %word_grid) {
        my $zone = $zones[$sent_idx];
        if (!defined $zone) {
            print STDERR "UNDEF_ZONE\n";
            print STDERR "$sent_idx/" . (scalar @zones) . "\n";
            print STDERR $doc->full_filename . "\n";
            foreach my $word_idx (keys %{$word_grid{$sent_idx}}) {
                print STDERR $word_grid{$sent_idx}{$word_idx} . "\n";
            }
        }
        my $aroot = $zone->get_atree;
        my @all_anodes = $aroot->get_descendants({ordered=>1});
        
        my @our_tokens = map {$_->form} @all_anodes;
        my @stanford_tokens = map {$_->getWord} @{$result->toArray->[$sent_idx]->getTokens->toArray};

        foreach my $word_idx (keys %{$word_grid{$sent_idx}}) {
            $t_mentions{$sent_idx}{$word_idx} = mention_descr_2_tnode(\@all_anodes, $token_align->{$word_idx}, $word_grid{$sent_idx}{$word_idx});
        }
    }

    # add links between tnodes
    foreach my $coref_info (@coref_links) {
        my $ante_tnode = $t_mentions{$coref_info->{src_sent}}{$coref_info->{src_idx}};
        my $anaph_tnode = $t_mentions{$coref_info->{tgt_sent}}{$coref_info->{tgt_idx}};
        $anaph_tnode->add_coref_text_nodes($ante_tnode);
    }
}

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
