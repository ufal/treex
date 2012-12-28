package Treex::Block::A2T::EN::SetTense;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# TODO: 'inf' is sometimes assigned but full fin/inf processing is TODO

# debug only
my $forms;

sub process_tnode {
    my ($self, $tnode) = @_;
    # return if $tnode->nodetype ne 'complex';

    if (defined $tnode->gram_sempos && $tnode->gram_sempos eq 'v') {
        my @anodes = $self->get_anodes($tnode);
        
        # debug only
        $forms = join ' ', ( map { $_->form } @anodes );
        
        my $full_verb = pop @anodes;
        my ($transcribed, $flags1) = $self->transcribe_aux(\@anodes);
        push @$transcribed, ( $self->transcribe_full($full_verb) );
        my $flags2 = $self->analyze_tense($transcribed);
        my $tense = $self->finalize($flags1, $flags2);
        $tnode->wild->{tense} = $tense;
        
        # debug only
        log_info $forms . ': ' . (join ',', keys %$tense);
    }
    
    return;
}

sub get_anodes {
    my ($self, $tnode) = @_;

    my @anodes = grep { $_->tag =~ /^MD|VB/ }
        $tnode->get_anodes( { ordered => 1 } );

    # TODO might want to add other aux nodes as well,
    # such as 'able'

    return @anodes;
}

    # ...and "be able to".
    #if ( all { $is_aux_lemma{$_} } qw(be able to) ) {
    #    $tnode->set_gram_deontmod('fac');
    #    if ( $is_aux_form{unable} ) {
    #        $tnode->set_gram_negation('neg1');
    #    }
    #}


my %lemma_tag_transcriptions = (
    be_VB  => 'be',
    be_VBP => 'be',
    be_VBZ => 'be',
    be_VBD => 'were',
    be_VBN => 'been',
    be_VBG => 'being',
    have_VB  => 'have',
    have_VBP => 'have',
    have_VBZ => 'have',
    have_VBD => 'had',
    have_VBN => 'had',
    have_VBG => 'having',
);

my %modal_flags = (
    must   => 'deb',
    should => 'hrt',
    ought  => 'hrt',
    want   => 'vol',
    can    => 'poss',
    could  => 'poss',
    may    => 'perm',
    might  => 'perm',
);

my %cnd_flags = (
    would  => 1,
    should => 1,
    ought  => 1,
    could  => 1,
    might  => 1,
);

# TODO handle 'be able to'

sub transcribe_aux {
    my ($self, $nodes) = @_;

    my @transcribed = ();
    my @flags = ();

    foreach my $node (@$nodes) {
        
        my $form = $node->form;
        my $lemma = $node->lemma;
        my $tag = $node->tag;

        if ( defined $lemma && defined $tag ) {
            
            my $transcription = $lemma_tag_transcriptions{ $lemma . '_' . $tag };

            # have to handle "have to" explicitly
            # because "have" itself is recognized as an auxiliary verb
            if ( $lemma eq 'have' && $node->get_next_node()->lemma eq 'to' ) {
                push @flags, 'deb';
            }

            # common auxiliary verbs get transcribed
            # and will be handled in analyze_tense()
            elsif ( defined $transcription ) {
                push @transcribed, $transcription;
            }

            # other aux verbs (incl. modals) are handled extra
            else {
                
                my $modal_flag = $modal_flags{$lemma};
                my $cnd_flag = $cnd_flags{$lemma};

                # modal (and maybe also conditional)
                if ( defined $modal_flag ) {
                    push @flags, 'modal';
                    push @flags, $modal_flag;
                    if ( defined $cnd_flag ) {
                        push @flags, 'cnd';
                    }

                    if ( $tag =~ /^VB[DN]$/) {
                        push @flags, 'past';                    
                    }
                    elsif ( $tag =~ /^VBG$/) {
                        push @flags, 'cont';                    
                    }
                }

                # conditional
                elsif ( defined $cnd_flag ) {
                    push @flags, 'cnd';
                }
                
                # do
                elsif ( $lemma eq 'do') {
                    if ( $tag =~ /^VB[PZ]?$/ ) {
                        # ignore
                    }
                    elsif ( $tag =~ /^VBD$/ ) {
                        push @flags, 'past';
                    }
                    else {
                       log_warn "SetTense: Cannot resolve aux '$form'!"; 
                    }
                }

                # will
                elsif ( $lemma eq 'will' && $tag ne 'VBG') {
                    push @flags, 'fut';
                }
                
                # shall TODO what exactly is shall? :-)
                elsif ( $lemma eq 'shall' && $tag ne 'VBG') {
                    push @flags, 'fut';
                }
                
                # going to
                elsif ( $lemma eq 'go' && $tag eq 'VBG') {
                    push @flags, 'gonna';
                }
                
                else {
                    push @flags, 'ERR';                
                    log_warn "SetTense: Cannot resolve '$form'!"; 
                    }
            }
        }
        else {
            log_warn "SetTense: node $form has no lemma/tag!";
        }
    }

    return (\@transcribed, \@flags);
}

my %tag_transcriptions = (
    VB => 'love',
    VBP => 'love',
    VBZ => 'love',
    VBD => 'loved',
    VBN => 'loved',
    VBG => 'loving',
);

sub transcribe_full {
    my ($self, $full) = @_;

    my $result = $tag_transcriptions{ $full->tag };
    if ( !defined $result ) {
        log_warn "SetTense: cannot process full verb '" . $full->form . "'!";
        $result = 'love';
    }
    
    return $result;
}

my %signature2flags = (
    'love' => [ ],
    'loved' => [ 'past' ],
    'have loved' => [ 'perf' ],
    'be loving' => [ 'cont' ],
    'be loved' => [ 'pass' ],
    'had loved' => [ 'past', 'perf' ],
    'were loving' => [ 'past', 'cont' ],
    'were loved' => [ 'past', 'pass' ],
    'have been loving' => [ 'perf', 'cont' ],
    'have been loved' => [ 'perf', 'pass' ],
    'be being loved' => [ 'cont', 'pass' ],
    'had been loving' => [ 'past', 'perf', 'cont' ],
    'were being loved' => [ 'past', 'cont', 'pass' ],
    'had been loved' => [ 'past', 'perf', 'pass' ],
    'have been being loved' => [ 'perf', 'cont', 'pass' ],
    'had been being loved' => [ 'past', 'perf', 'cont', 'pass' ],
    
    # some infinitives (I am not very sure about the flags)
    'loving' => [ 'cont', 'inf' ],
    'being loved' => [ 'cont', 'pass', 'inf' ],
    'having loved' => [ 'past', 'cont', 'inf' ],
    'been loving' => [ 'past', 'cont', 'inf' ],
    'having been loving' => [ 'past', 'cont', 'inf' ],
    'been loved' => [ 'past', 'pass', 'inf' ],
    'having been loved' => [ 'past', 'cont', 'pass', 'inf' ],
    'been being loved' => [ 'past', 'cont', 'pass', 'inf' ],
    'having been being loved' => [ 'past', 'cont', 'pass', 'inf' ],
);

sub analyze_tense {
    my ($self, $resolved) = @_;

    my $signature = join ' ', @$resolved;
    my $flags = $signature2flags{$signature};
    if ( defined $flags ) {
        return $flags;
    }
    else {
        log_warn "SetTense: Cannot resolve '$signature'!";
        return [ 'ERR' ];
    }

}

sub finalize {
    my ($self, $flags1, $flags2) = @_;

    my %tense = ();

    # merge flags
    my @flags = (@$flags1, @$flags2);
    foreach my $flag (@flags) {
        $tense{$flag} = 1;
    }

    # fix some special cases
    if ( $tense{perf} && $tense{cnd} ) {
        # would have loved
        $tense{past} = 1;
        delete $tense{perf};
    }
    if ( $tense{perf} && $tense{modal} ) {
        # must have loved
        $tense{past} = 1;
        delete $tense{perf};
    }
    if ( $tense{gonna} && !$tense{past} ) {
        # are going to love (but not were going to love)
        $tense{fut} = 1;
    }
    if ( !$tense{past} && !$tense{fut} ) {
        # TODO or infinitive (check whether there is a child pronoun)
        $tense{pres} = 1;
    }

    return \%tense;
}


1;

=head1 NAME 

Treex::Block::A2T::EN::SetTense

=head1 DESCRIPTION

Work in progress! Has to be tested and TODOs have to be filled.

Creates a wild->{tense} hash reference for each verb.
The hash contains flags, such as pres, perf, cnd, vol...

Partly based on A2T::EN::SetGrammateme and A2T::EN::MarkClauseHeads.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

