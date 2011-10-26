package Treex::Block::Write::LayerAttributes::MatchingOrEmpty;

use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

has 'pattern' => ( isa => 'Str', is => 'ro', required => 1 );

has 'invert_match' => ( isa => 'Bool', is => 'ro', default => 0 );

has 'empty_value' => ( isa => 'Str', is => 'ro', default => '' );

# Return the t-lemma and sempos
sub modify_single {

    my ( $self, $matching, $value ) = @_;

    return undef if ( !defined($matching) );

    my $pattern = $self->pattern;

    return $self->empty_value if ( ( $self->invert_match ) == ( $matching =~ m/$pattern/ ) );
    return ($value);
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::MatchingOrEmpty

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::MatchingOrEmpty->new({
        pattern => '^(ACT|PAT|ADDR|ORIG|EFF)$'
    });
    
    my $parent_tlemma = 'ministr';
    my $functor = 'RSTR';   

    print $modif->modify_all( $parent_tlemma, $functor ); # prints ''
    
    my $parent_tlemma = 'vládnout';
    my $functor = 'ACT';
    
    print $modif->modify_all( $parent_tlemma, $functor ); # prints 'vládnout'  

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes two values. If the first one
matches the pre-set pattern, the returned value is the second value, otherwise the returned value is empty
(or a pre-set "empty" string).  

=head2 Example (from synopsis)

Take the C<functor> of a t-node and the C<t_lemma> of its (effective) parent and set-up the pattern to match 
all actant functors. Then, if the functor is an actant, the parent's C<t_lemma> will be returned,
if not, the result will be an empty value (so that all adverbials are grouped, but actants split according 
to the parent t-lemma).

=head1 PARAMETERS

=over

=item pattern

The matching pattern (regular expression). This parameter is required.

=item invert_match

If set to 1, this will invert the match. Default: 0.

=item empty_value

The value that will be returned as 'empty'. Default: empty string. 

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
