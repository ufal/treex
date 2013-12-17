package Treex::Block::A2A::CS::FixVerbByEnSubject;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ( $d->{pos} eq 'V' ) {

        if ( $dep->lemma =~ /podařit/ ) {

            # is formed differently in Czech and in English
            return;
        }

        if ( $d->{gen} =~ /[N-]/ && $d->{num} eq 'S' && $d->{pers} =~ /[3-]/ ) {
            my @dep_children = $dep->get_children();
            foreach my $child (@dep_children) {
                if ( $child->form eq 'se' && $child->tag =~ /^P/ ) {

                    # might be passival construction
                    # ("ono se to udělalo" style)
                    return;
                }
            }
        }

        # try to find the English subject and use it
        # TODO: handle auxiliaries, infinitives etc.
        my $en_verb = $self->en($dep);
        if ( !defined $en_verb ) {
            return;
        }
        my $en_subject;
        foreach my $en_child ( $en_verb->get_children() ) {
            if ( $en_child->afun eq 'Sb' && $en_child->tag eq 'PRP' ) {
                $en_subject = $en_child;
            }
        }
        if ( !defined $en_subject ) {
            return;
        }

        # subject has been found, proceed to fixing
        $self->logfix1( $dep, "VerbByEnSubject" );
        my $fixed = 0;
        my $lemma = $en_subject->lemma;

        # number
        my $num = $d->{num};

        if ( $num =~ /[SPW]/ ) {
            if ( $lemma =~ /^(I|he|she|it)$/ ) {
                $num = 'S';
            } elsif ( $lemma =~ /^(we|they)$/ ) {
                $num = 'P';
            }
            if ( $num ne $d->{num} ) {
                $fixed = 1;
                substr( $d->{tag}, 3, 1, $num );
            }
        }

        # gender
        my $gen = $d->{gen};

        if ( $gen =~ /[MIFNTYQ]/ ) {
            if ( $lemma eq 'he' ) {
                $gen = 'M';
            } elsif ( $lemma eq 'she' ) {
                $gen = 'F';
            }

            # 'it' omitted on purpose (but to be tested)
            if ( $gen ne $d->{gen} ) {
                $fixed = 1;
                substr( $d->{tag}, 2, 1, $gen );
            }
        }

        # person
        my $pers = $d->{pers};
        if ( $pers =~ /[123]/ ) {
            if ( $lemma =~ /^(I|we)$/ ) {
                $pers = '1';
            } elsif ( $lemma eq 'you' ) {
                $pers = '2';
            } elsif ( $lemma =~ /^(he|she|it|they)$/ ) {
                $pers = '3';
            }
            if ( $pers ne $d->{pers} ) {
                $fixed = 1;
                substr( $d->{tag}, 7, 1, $pers );
            }
        }

        if ($fixed) {
            if ( $d->{tag} =~ /^V[sp]/ ) {
                substr( $d->{tag}, 2, 2, $self->gn2pp( $gen . $num ) );
            }
            $self->regenerate_node( $dep, $d->{tag} );
            $self->logfix2($dep);
        }
    }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixVerbByEnSubject - fixing the form of the verb
by looking at the subject of its aligned counterpart

=head1 DESCRIPTION

Try to guess the gender, number and person from the English sentence
if the English subject is a personal pronoun.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
