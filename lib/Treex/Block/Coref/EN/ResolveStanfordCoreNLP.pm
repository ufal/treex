package Treex::Block::Coref::EN::ResolveStanfordCoreNLP;
use Moose;
use utf8;
use Treex::Core::Common;
use Lingua::StanfordCoreNLP;
use Text::Unidecode;

extends 'Treex::Block::Coref::ResolveFromRawText';

has '_pipeline' => ( is => 'ro', builder => '_build_pipeline');

sub _build_pipeline {
    my ($self) = @_;

    # must be here to access the inline class Lingua::StanfordCoreNLP::Pipeline
    Inline->init();
    my $pipeline = new Lingua::StanfordCoreNLP::Pipeline;
    my $props = $pipeline->getProperties();
    $props->put('annotators', 'tokenize, ssplit, pos, lemma, ner, parse, dcoref');
    $props->put('tokenize.whitespace', 'true');
    #$props->put('tokenize.options', 'americanize=false');
    #$props->put('tokenize.options', 'ptb3Escaping=false');
    $pipeline->setProperties($props);
    #print STDERR "BUILDING CORENLP PIPELINE\n";
    
    return $pipeline;
}


sub _normalize_token {
    my ($w) = @_;
    $w =~ s/\pZ+//g;
    $w =~ s/\\//g;
    my $w2 = unidecode($w);
    return $w2;
}

#sub process_start {
#    my ($self) = @_;
#    $self->_pipeline;
#}

sub process_document {
    my ($self, $doc) = @_;

    my $raw_text = $self->_prepare_raw_text($doc);

    my $result;
    eval {
        $result = $self->_pipeline->process($raw_text);
    };
    if ($@){
        log_warn "Skipping document " . $doc->full_filename() . " due to: $@";
        return;
    }
    
    # collect coreference links and create a grid of mentions indexed by (sent_idx X word_idx) in order to process it sequentially
    my @coref_links = ();
    my %word_grid = ();
    for my $sentence (@{$result->toArray()}) {
        #if ($doc->full_filename eq "data/dev.pcedt/wsj_2008") {
        #    print STDERR $sentence->getIDString . ": ". $sentence->getSentence . "\n";
        #}
        for my $coref (@{$sentence->getCoreferences->toArray()}) {
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

    my @atrees = map {$_->get_tree($self->language, 'a', $self->selector)} $doc->get_bundles;
    my @our_anodes = map {[$_->get_descendants({ordered=>1})]} @atrees;
    my @our_tokens = map {[map {_normalize_token($_->form)} @$_]} @our_anodes;
    my @stanford_tokens = map {[map {_normalize_token($_->getWord())} @{$_->getTokens->toArray()}]} @{$result->toArray()};
    my $token_align = $self->_align_arrays(\@stanford_tokens, \@our_tokens);
    #print STDERR Dumper($token_align);


    # collect a tnode for every mention in the mention grid
    my %t_mentions = ();
    foreach my $sent_idx (keys %word_grid) {
        foreach my $word_idx (keys %{$word_grid{$sent_idx}}) {
            my ($stanford_sent_idx, $stanford_word_idx) = split /,/, $token_align->{"$sent_idx,$word_idx"};
            my $anode = $our_anodes[$stanford_sent_idx][$stanford_word_idx]; 
            my ($tnode) = ($anode->get_referencing_nodes('a/lex.rf'), $anode->get_referencing_nodes('a/aux.rf'));
            $t_mentions{$sent_idx}{$word_idx} = $tnode;
        }
        #if (!defined $zone) {
        #    print STDERR "UNDEF_ZONE\n";
        #    print STDERR "$sent_idx/" . (scalar @zones) . "\n";
        #    print STDERR $doc->full_filename . "\n";
        #    foreach my $word_idx (keys %{$word_grid{$sent_idx}}) {
        #        print STDERR $word_grid{$sent_idx}{$word_idx} . "\n";
        #    }
        #}
    }

    # add links between tnodes
    foreach my $coref_info (@coref_links) {
        my $ante_tnode = $t_mentions{$coref_info->{src_sent}}{$coref_info->{src_idx}};
        my $anaph_tnode = $t_mentions{$coref_info->{tgt_sent}}{$coref_info->{tgt_idx}};
        #print "ADDING COREF: " . $anaph_tnode->id . " -> " . $ante_tnode->id . "\n";
        if (defined $anaph_tnode && defined $ante_tnode && ($anaph_tnode != $ante_tnode)) {
            $anaph_tnode->add_coref_text_nodes($ante_tnode);
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Coref::EN::ResolveStanfordCoreNLP

=head1 DESCRIPTION

Coreference resolver for English wrapping Stanford CoreNLP resolver.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
