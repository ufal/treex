package Treex::Block::A2A::CS::FixNounNumber;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ( $d->{tag} =~ /^N/ && $self->en($dep) ) {

        $self->logfix1( $dep, "NounNumber" );

        my $fixed = 0;
        if ($d->{num} eq 'S'
            && $self->en($dep)
            && $self->en($dep)->tag
            && $self->en($dep)->tag eq 'NNS' # TODO NNPS, verbs
            )
        {    #cs singular, en plural
            my $setnum = 'P';
            $d->{tag} =~ s/^(...)./$1$setnum/;
            my $old_form = $dep->form;
            my $new_form_shouldbe = $self->get_form( $dep->lemma, $d->{tag} );
            if ( !$new_form_shouldbe || lc($old_form) ne lc($new_form_shouldbe) ) {    #the form is about to change
                                                                                       #maybe mistake of tagger, not mistake of translation -> is there any case that would match the original form?
                my $new_tag = $d->{tag};                                               #do not change $d->{tag}
                for ( my $case = 1; $case <= 7; $case++ ) {
                    $new_tag =~ s/^(....)./$1$case/;
                    my $new_form = $self->get_form( $dep->lemma, $new_tag );
                    if ( $new_form && lc($old_form) eq lc($new_form) ) {               #no change of form -> probably better
                        $d->{tag} = $new_tag;                                          #now do change $d->{tag}
                        $fixed = 1;
                        last;
                    }
                }    #if same form not found, $fixed stays at 0 -> no change made
            }
            else {    #the forms stays the same -> just change the number
                $fixed = 1;
            }
        }

        # change from plural to singular does not work properly because of uncountables and similar EN-CS discrepancies
        #
        #         elsif ($d->{num} eq 'P' && $self->en($dep)->tag eq 'NN') { #cs plural, en singular
        #             my $setnum = 'S';
        #             $d->{tag} =~ s/^(...)./$1$setnum/;
        #             $fixed = 1;
        #         }

        if ($fixed) {

            #$self->regenerate_node($dep, $d->{tag});
            $dep->set_tag( $d->{tag} );
            $self->logfix2($dep);
        }
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixNounNumber

=head1 DESCRIPTION

Fixing Noun number (and sometimes case as well) according to en_aligned_node
number. Assumes that the form is correct and only the tag is incorrect (error
of tagger), and so it does only such fixes, where the form is preserved.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.
