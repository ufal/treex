package Treex::Block::A2T::EN::SetTense;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'log_to_console' => ( is => 'rw', isa => 'Bool', default => 0 );

sub process_tnode {
    my ($self, $tnode) = @_;

    # analyze only verbs
    if ( defined $tnode->get_lex_anode
        && $tnode->get_lex_anode->tag =~ /^VB/
    ) {
        
        # analyze the tense 
        my @anodes = $self->get_anodes($tnode);
        my $tense = undef;
        my $err = 0;
        do {
            my ($transcribed, $flags1) = $self->transcribe_nodes(\@anodes);
            my $flags2 = $self->analyze_tense($transcribed);
            my $flags3 = $self->add_inf_and_neg($tnode);
            $tense = $self->finalize($flags1, $flags2, $flags3);

            # if there has been an error,
            # remove the first anode and try again
        } while ( $tense->{ERR} && ($err = 1) && (shift @anodes) );

        # add 'WARN' if there has been an error
        if ( $err ) {
            # there has been an error - note that with a WARN
            $tense->{WARN} = 1;
        }

        # set the tense
        $tnode->wild->{tense} = $tense;
        
        # debug only
        if ($self->log_to_console) {
            my $forms_string = join ' ', (
                map { $_->form } $tnode->get_anodes( { ordered => 1 } ) );
            my $tense_string = join ',', keys %$tense;
            log_debug "$forms_string: $tense_string";
        }
    }
    
    return;
}

# verbs, modals, able
# TODO allowed?
sub get_anodes {
    my ($self, $tnode) = @_;

    my @anodes = grep { $_->tag =~ /^MD|VB/ || $_->lemma eq 'able' }
        $tnode->get_anodes( { ordered => 1 } );

    return @anodes;
}

# aux transcriptions
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

# full transcriptions
my %tag_transcriptions = (
    VB => 'love',
    VBP => 'love',
    VBZ => 'love',
    VBD => 'loved',
    VBN => 'loved',
    VBG => 'loving',
);

# TODO: only flag the modal lemma,
# SetGrammateme will set the appropriate deontmod
my %modal_flags = (
    must   => 'deb',
    should => 'hrt',
    ought  => 'hrt',
    want   => 'vol',
    can    => 'poss',
    could  => 'poss',
    may    => 'perm',
    might  => 'perm',
    # able => 'fac',
    # have => 'deb',
);

my %cdn_flags = (
    would  => 1,
    should => 1,
    ought  => 1,
    could  => 1,
    might  => 1,
);

my %be_carry = (
    be    => undef,
    were  => 'VBD',
    been  => 'VBN',
    being => 'VBG',
);

sub transcribe_nodes {
    my ($self, $nodes) = @_;

    my @transcribed = ();
    my @flags = ();
    my $carry;
    my $remaining = scalar(@$nodes);

    foreach my $node (@$nodes) {
        
        $remaining--;
        my $form = $node->form;
        my $lemma = $node->lemma;
        my $tag = $node->tag;
        if ( defined $carry ) {
            if ( $tag !~ /^VBP?/ ) {
                push @flags, 'ERR'; # TODO or only WARN?
                log_warn "SetTense: cannot carry $carry onto $tag!";
            }
            $tag = $carry;
            $carry = undef;
        }

        if ( defined $lemma && defined $tag ) {
            
            # last word (i.e. the full verb)
            if ( $remaining == 0 ) {
                my $transcription = $tag_transcriptions{$tag};
                if ( defined $transcription ) {
                    push @transcribed, $transcription;
                }
                else {
                    push @flags, 'WARN';
                    push @transcribed, 'love';
                    log_warn "SetTense: cannot process full verb '" . $form . "'!";
                }
            }

            # else an auxiliary
            else {
                my $transcription = $lemma_tag_transcriptions{ $lemma . '_' . $tag };

                # have to handle "have to" explicitly
                # because "have" itself is recognized as an auxiliary verb
                if ( $lemma eq 'have' && next_is_to($node) ) {
                    push @flags, 'deb';
                    $carry = $tag;
                }

                # common auxiliary verbs get transcribed
                # and will be handled in analyze_tense()
                elsif ( defined $transcription ) {
                    push @transcribed, $transcription;
                }

                # other aux verbs (incl. modals) are handled extra
                else {

                    # modals and conditionals
                    my $modal_flag = $modal_flags{$lemma};
                    my $cdn_flag = $cdn_flags{$lemma};

                    # modal (and maybe also conditional)
                    if ( defined $modal_flag ) {
                        push @flags, $modal_flag;
                        
                        # carry the tag (but do not carry MD)
                        if ( $tag =~ /^VB/ ) {
                            $carry = $tag;
                        }

                        # also check for cdn
                        if ( defined $cdn_flag ) {
                            push @flags, 'cdn';
                        }
                    }

                    # conditional
                    elsif ( defined $cdn_flag ) {
                        push @flags, 'cdn';
                    }

                    # do
                    elsif ( $lemma eq 'do') {
                        if ( $tag =~ /^VB[PZD]?$/ ) { # do does did
                            $carry = $tag;
                        }
                        else {
                            push @flags, 'WARN';
                            log_warn "SetTense: Cannot resolve aux '$form'!"; 
                        }
                    }

                    # will and shall;
                    # 'shall' is treated simply as a variant of 'will',
                    # which is probably the most common case,
                    # although 'hrt' modality might also be flagged
                    elsif ( $lemma =~ /^will|shall$/ && $tag ne 'VBG') {
                        push @flags, 'fut';
                    }

                    # [be] going to
                    elsif ( $lemma eq 'go'
                        && $tag eq 'VBG'
                        && next_is_to($node)
                    ){
                        push @flags, 'gonna';

                        # handle preceding [be]
                        my $be = pop @transcribed;
                        if (defined $be) {
                            if ( $be =~ /^be|were/ ) {
                                # be being been were - carry the tense
                                $carry = $be_carry{$be};
                            }
                            else {
                                # not [be] - put it back and signal error
                                push @transcribed, $be;
                                push @flags, 'WARN';
                                log_warn "SetTense: expecting BE before GOING TO!"; 
                            }
                        }
                        else {
                            # missing [be]
                            push @flags, 'inf';
                        }
                    }

                    # [be] able to
                    elsif ( $lemma eq 'able' && next_is_to($node) ) {
                        push @flags, 'fac';

                        # 'unable' handled extra
                        if ( $form eq 'unable' ) {
                            push @flags, 'neg';
                        }

                        # handle preceding [be]
                        my $be = pop @transcribed;
                        if (defined $be) {
                            if ( $be =~ /^be|were/ ) {
                                # be being been were - carry the tense
                                $carry = $be_carry{$be};
                            }
                            else {
                                # not [be] - put it back and signal error
                                push @transcribed, $be;
                                push @flags, 'WARN';
                                log_warn "SetTense: expecting BE before ABLE TO!"; 
                            }
                        }
                        else {
                            # missing [be]
                            push @flags, 'WARN';
                            log_warn "SetTense: expecting BE before ABLE TO!"; 
                        }
                    }

                    else {
                        push @flags, 'ERR';                
                        log_warn "SetTense: Cannot resolve form '$form'!"; 
                    }
                }
            }
        }
        else {
            log_warn "SetTense: node $form has no lemma/tag!";
        }
    }

    return (\@transcribed, \@flags);
}

sub next_is_to {
    my ($anode) = @_;

    my $next = $anode->get_next_node;
    if (defined $next && defined $next->lemma && $next->lemma eq 'to') {
        return 1;
    }
    else {
        return 0;
    }

}

# all signatures are written for the 1st person pl,
# only 'be' is used instead of 'are'
# e.g. "we love", "we be being loved"...
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
        log_warn "SetTense: Cannot resolve signature '$signature'!";
        return [ 'ERR' ];
    }

}

sub add_inf_and_neg {
    my ($self, $tnode) = @_;

    my @flags = ();

    # add 'neg' if negated
    if ( any { $_->lemma eq 'not' } $tnode->get_anodes ) {
        push @flags, 'neg';
    }

    # add 'inf' if not head of clause
    if ( !$tnode->is_clause_head ) {
        push @flags, 'inf';
    }

    return \@flags;
}

sub finalize {
    my ($self, $flags1, $flags2, $flags3) = @_;

    my %tense = ();

    # merge flags
    my @flags = (@$flags1, @$flags2, @$flags3);
    foreach my $flag (@flags) {
        $tense{$flag} = 1;
    }

    # store the modality type
    my $modal = first { /^deb|hrt|vol|poss|perm|fac$/ } @flags;
    if ( defined $modal ) {
        $tense{modal} = $modal;
    }

    # fix some special cases
    if ( $tense{perf} && $tense{cdn} ) {
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
        $tense{pres} = 1;
    }

    return \%tense;
}

1;

=head1 NAME 

Treex::Block::A2T::EN::SetTense - detect the English tense

=head1 DESCRIPTION

Creates a C<wild-&gt;{tense}> hash reference for each verb.
The hash contains flags, such as pres, perf, cdn, vol...
Infitiveness and negation are also included.
All of the flags (except for C<modal>) are binary - 
either the flag is present (and has the value of C<1>),
or it is not present (which is the "default").

=over

=item past, pres, fut

Exactly one of these is always set -
even for infinitives, where C<pres> is the default.

=item perf

=item cont

=item pass

=item gonna

=item cdn

=item modal

=item neg

=item inf

=back

Partly based on L<Treex::Block::A2T::EN::SetGrammateme>.

=head1 FUTURE WORK

Completely ignores the VBD/VBN distinction, except for the verb 'to be'.
In most cases, the VB/VBP/VBZ distinction is also ignored.
The motivation is that these distinctions are redundant if the verb is
correctly formed, probably with the only exception of the verb 'to be'
(and also that the tagger is easily mistaken if some of the word forms are
identical for different tags).
However, in practice it leads to the fact that many erroneous forms are
thought to be correct -- which can be seen both as an advantage an an
disadvantage.
Also, it makes infinitives detection harder.

Some other ideas for "deeper" tenses (and probably for a separate block):

=over

=item present continuous can express future

if there is a future expression, such as 'tomorrow', 'next week',
'on Monday', 'today', 'at 12:34'
(except for 'now', 'at the moment')

=item reported speech

but not sure what the output should be

=item conditionals

it should be possible to detect 0th/1st/2nd/3rd/mixed
conditional - at least in unambiguous cases

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012-2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

