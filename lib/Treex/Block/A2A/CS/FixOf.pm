package Treex::Block::A2A::CS::FixOf;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    # 'of' preposition being a head of an inflected word
    
    if (!$en_counterpart{$dep}) {
	return;
    }
    my $aligned_parent = $en_counterpart{$dep}->get_eparents({first_only=>1, or_topological => 1});

    if (
	$g->{tag} =~ /^N/
	&& $d->{tag} =~ /^....[1-7]/
	&& $aligned_parent
	&& $aligned_parent->form
	&& $aligned_parent->form eq 'of'
	&& !$self->isName($dep)
	) {

	# now find the correct case and number for this situation
	my $original_case = $d->{case};
	my $new_case = 2;

	if ($new_case != $original_case) {

            my $original_num = $d->{num};
            my $new_num = $original_num;

            my $new_tag = $d->{tag};
            $new_tag =~ s/^(....)./$1$new_case/;
            my $old_form = $dep->form;
            my $new_form = $self->get_form( $dep->lemma, $new_tag );

            # maybe the form is correct but the number is tagged incorrcetly
            if ( !$new_form || lc($old_form) ne lc($new_form) ) {
                my $try_num = $self->switch_num($original_num);
                $new_tag =~ s/^(...)../$1$try_num$new_case/;
                $new_form = $self->get_form( $dep->lemma, $new_tag );
                if ( $new_form && lc($old_form) eq lc($new_form) ) {
                    # keep form, change number in tag
                    $new_num = $try_num;
                }
            }

            $d->{tag} =~ s/^(...)../$1$new_num$new_case/;
	    
	    $self->logfix1( $dep, "Of" );
	    $self->regenerate_node( $dep, $d->{tag} );
	    $self->logfix2($dep);
	}

    }
}

1;

=over

=item Treex::Block::A2A::CS::FixOf

The English preposition 'of' is often translated into Czech by using the genitive case (if a preposition is not used).

=back

=cut

# Copyright 2011 Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
