package Treex::Block::A2A::CS::FixPrepositionalCase;

use Moose;
use Treex::Core::Common;

use CzechMorpho;

extends 'Treex::Block::A2A::CS::FixAgreement';

has '_analyzer' => (
    is      => 'rw',
    isa     => 'Object',
    lazy    => 1,
    default => sub { CzechMorpho::Analyzer->new() }
);

#has 'skip_prep_tag' => ( is => 'rw', isa => 'Str', default => "s_2 s_4 za_2 v_4 mezi_4 z_2 před_4 o_4 po_4" );

has '_skip_prep_tag' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { ( {} ) }
);

sub BUILD {
    my $self = shift;

    # my @skip = split / /, $self->skip_prep_tag;
    my @skip = (
        's_2', 's_4', 'za_2', 'v_4', 'mezi_4', 'z_2',
        'před_4', 'o_4', 'po_4'
    );
    foreach my $skip_pt (@skip) {
        $self->_skip_prep_tag->{$skip_pt} = 1;
    }

    return;
}

sub fix {

    # gov = governing preposition, dep = dependent of preposition
    my ( $self, $dep, $gov, $d, $g ) = @_;

    # gov is prep, dep is not and they do not agree in case (which they should)
    # (conditions adapted from
    # W2A::CS::FixPrepositionalCase and A2A::CS::FixPrepositionNounAgreement)
    if ($g->{afun}   eq 'AuxP'
        && $g->{pos} eq 'R'
        && $g->{case} =~ /[1-7]/

        && $d->{afun} ne 'AuxP'
        && $d->{pos} =~ /[NAPC]/
        && $d->{case} ne 'X'

        && $g->{case} ne $d->{case}
        )
    {

        # set new cases and/or lemmas
        my $do_correct = 0;

        # the tags and lemmas to set (default: keep)
        my $gov_tag   = $g->{tag};
        my $gov_lemma = $gov->lemma;
        my $dep_tag   = $d->{tag};
        my $dep_lemma = $dep->lemma;

        # possible tags and lemmas for the forms
        # (hash refs where case is the key)
        my ( $tags_dep, $lemmas_dep ) = $self->_get_possible_cases(
            $dep->form, $d, $dep->lemma
        );
        my ( $tags_gov, $lemmas_gov ) = $self->_get_possible_cases(
            $gov->form, $g, $gov->lemma
        );

        # try to find the least painful way
        # to correct the pos tags and/or lemmas
        if ( $tags_dep->{ $g->{case} } ) {

            # correct the tag:
            # use the preposition's case if it's OK with the dep form
            $do_correct = 1;
            $dep_tag    = $tags_dep->{ $g->{case} };
            $dep_lemma  = $lemmas_dep->{ $g->{case} };

        } elsif (
            any {
                substr( $_->tag, 4, 1 ) eq $g->{case};
            }
            $gov->get_echildren()
            )
        {

            # do not correct case of prepositions
            # that have (other) children with a matching case
            $do_correct = 0;

        } elsif ( $tags_gov->{ $d->{case} } ) {

            # correct the tag:
            # use the dep's case if it's OK with the preposition
            $do_correct = 1;
            $gov_tag    = $tags_gov->{ $d->{case} };
            $gov_lemma  = $lemmas_gov->{ $d->{case} };

        } else {

            # find common case for dep and gov (first matching)
            # (order of cases probably should be from more probable cases
            # to less probable cases; however, no effect has been observed)
            my ($common_case) = grep {
                $tags_gov->{$_} and $tags_dep->{$_}
            } ( 7, 6, 4, 3, 2, 5, 1 );

            # if there is a possible common case,
            # fix both the dep and the preposition
            if ($common_case) {
                $do_correct = 1;
                $dep_tag    = $tags_dep->{$common_case};
                $dep_lemma  = $lemmas_dep->{$common_case};
                $gov_tag    = $tags_gov->{$common_case};
                $gov_lemma  = $lemmas_gov->{$common_case};
            }

        }

        if ($do_correct) {

            # skip unpreferred prep-tag combinations
            my ($prep_lemma_coarse) = split /-/, $gov_lemma;
            my $prep_case = substr( $dep_tag, 4, 1 );
            my $skip_pt = $prep_lemma_coarse . '_' . $prep_case;
            if ( $self->_skip_prep_tag->{$skip_pt} ) {
                return;
            }

            $self->logfix1( $dep, "PrepositionalCase" );
            $gov->set_tag($gov_tag);
            $gov->set_lemma($gov_lemma);
            $dep->set_tag($dep_tag);
            $dep->set_lemma($dep_lemma);
            $self->logfix2($dep);
        }

    }

    return;
}

# Return a hash with keys set for cases this word form might be in
# (limit to the given POS)
# and values containg the corresponding tags
sub _get_possible_cases {

    my ( $self, $form, $orig_cats, $orig_lemma ) = @_;

    my $dists  = {};
    my $tags   = {};
    my $lemmas = {};

    my @analyses = $self->_analyzer->analyze($form);

    foreach my $analysis (@analyses) {

        my ( $pos, $gen, $num, $case ) = (
            $analysis->{tag} =~ m/^(.).(.)(.)(.)/
        );
        if ( $orig_cats->{pos} eq $pos && $case =~ /[1-7X]/ ) {

            # keep the distance from the current number and gender
            # as small as possible
            my $dist = 0;
            $dist++ if ( $orig_cats->{num} ne $num );

            # changing gender/lemma is more than changing number
            $dist += 2
                if (
                ( $orig_cats->{gen} ne $gen )
                or
                ( $orig_lemma ne $analysis->{lemma} )
                );

            if ( ( not $tags->{$case} ) or $dist < $dists->{$case} ) {
                $tags->{$case}   = $analysis->{tag};
                $lemmas->{$case} = $analysis->{lemma};
                $dists->{$case}  = $dist;
            }
        }
    }
    return ( $tags, $lemmas );
}

1;
__END__


=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPrepositionalCase

=head1 DESCRIPTION

Adapted from Treex::Block::W2A::CS::FixPrepositionalCase for needs of depfix.

Correction of wrong POS in prepositional phrases.

This block looks for all nodes that depend on a preposition and do not match 
its case. If their form can match the preposition's case with a different tag 
or the preposition can have a different case so that the two are congruent, 
the case of the node and/or its preposition is changed.

Some unfrequent preposition-case combinations are not used.

=head1 PARAMETERS

=TODO

A better testing / evaluation is required. Possibly this should be done the 
other way round -- looking at prepositions and examining their children.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

adapted by Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles 
University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.

