package Treex::Block::Coref::EN::ResolveStanfordCoreNLP;
use Moose;
use utf8;
use Treex::Core::Common;
use Lingua::StanfordCoreNLP;
use Text::Unidecode;

extends 'Treex::Core::Block';

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

sub _is_prefix {
    my ($s1, $s2) = @_;

    return undef if (!defined $s1 || !defined $s2);
    #print STDERR "$s1 $s2\n";
    my $is_prefix;
    if (length($s1) > length($s2)) {
        $is_prefix = ($s1 =~ /^\Q$s2/);
    }
    else {
        $is_prefix = ($s2 =~ /^\Q$s1/);
    }
    return $is_prefix;
}

sub _is_superfluous {
    my ($str1, $str2) = @_;
    
    # TODO can be changed to check whether it's a suffix of a previous word
    return 1 if ($str1 eq '.');
    return -1 if ($str2 eq '.');
    return 0 if ($str1 eq "labor" && $str2 eq "labour");
    return 0 if ($str1 eq "-LRB-" && $str2 eq "(");
    return 0 if ($str1 eq "-RRB-" && $str2 eq ")");
    return 0 if ($str1 eq "theater" && $str2 eq "theatre");
    return 0 if ($str1 eq "labeled" && $str2 eq "labelled");
    return 0 if ($str1 eq "meager" && $str2 eq "meagre");
    #log_warn "Neither '$str1' nor '$str2' are superflous.";
    #log_fatal "Luxembourg-based" if ($str1 eq "Luxembourg-based" || $str2 eq "Luxembourg-based");
    return 0;
}

sub align_arrays {
    my ($a1, $a2) = @_;

    #print STDERR Dumper($a1, $a2);

    my %align = ();

    my $i1 = 0; my $i2 = 0;
    my $j1 = 0; my $j2 = 0;
    #my $l_offset = length($a1->[$i1][$j1]) - length($a2->[$i2][$j2]);
    my $l_offset = 0;
    #my $l1 = 0; my $l2 = 0;
    #print STDERR scalar @$a1 . "\n";
    #print STDERR scalar @$a2 . "\n";
    while (($i1 < scalar @$a1) && ($i2 < scalar @$a2)) {
        #print STDERR Dumper($a1->[$i1], $a2->[$i2]);
        while (($j1 < @{$a1->[$i1]}) && ($j2 < @{$a2->[$i2]})) {

            my $s1 = $a1->[$i1][$j1];
            my $s2 = $a2->[$i2][$j2];
            if ($l_offset == 0 && !_is_prefix($s1, $s2)) {
                my $superfl = _is_superfluous($s1, $s2);
                if ($superfl > 0) {
                    $j1++;
                    next;
                }
                elsif ($superfl < 0) {
                    $j2++;
                    next;
                }
                else {
                    # TODO: HACK
                    $l_offset -= length($s1) - length($s2);
                }
            }

            $l_offset += length($s1) - length($s2);
            if ($l_offset) {
                #print STDERR "$i1:$j1 -> $i2:$j2\t($l_offset)\t$s1 $s2\n";
            }
            $align{$i1.",".$j1} = $i2.",".$j2 if (!defined $align{$i1.",".$j1});
            
            if ($l_offset < 0) {
                $l_offset += length($s2);
                $j1++;
            }
            elsif ($l_offset > 0) {
                $l_offset -= length($s1);
                $j2++;
            }
            else {
                $j1++; $j2++;
            }
            #print STDERR Dumper(\%align);
            #print STDERR ($j1 < @{$a1->[$i1]}) ? 1 : 0;
            #print STDERR ($j2 < @{$a2->[$i2]}) ? 1 : 0;
            #print STDERR ($l_offset != 0) ? 1 : 0;
            #print STDERR "\n";
            #exit if ($j1 > 50 || $j2 > 50);
        }
        if ($j1 >= @{$a1->[$i1]}) {
            $i1++; $j1 = 0;
        }
        if ($j2 >= @{$a2->[$i2]}) {
            $i2++; $j2 = 0;
        }
        #my $line = <STDIN>;
    }

    return \%align;
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

    # TODO test on documents consisting of independent segments (e.g. CzEng)
    my @zones = map {$_->get_zone($self->language, $self->selector)} $doc->get_bundles;

    my $result;
    eval {
        $result = $self->_pipeline->process(join "\n", map {$_->sentence} @zones);
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

    my @our_anodes = map {[$_->get_atree->get_descendants({ordered=>1})]} @zones;
    my @our_tokens = map {[map {_normalize_token($_->form)} @$_]} @our_anodes;
    my @stanford_tokens = map {[map {_normalize_token($_->getWord())} @{$_->getTokens->toArray()}]} @{$result->toArray()};
    my $token_align = align_arrays(\@stanford_tokens, \@our_tokens);
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

Pronoun coreference resolver for English using Stanford CoreNLP resolver.

Settings:
* English personal pronoun filtering of anaphor
* candidates for the antecedent are nouns from current (prior to anaphor) and previous sentence
* English pronoun coreference feature extractor
* using a model trained by a perceptron ranker

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
