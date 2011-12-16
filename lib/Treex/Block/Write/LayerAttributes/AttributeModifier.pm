package Treex::Block::Write::LayerAttributes::AttributeModifier;

use Moose::Role;
use Treex::Core::Log;


has 'return_values_names' => ( isa => 'ArrayRef', is => 'ro', required => 1 );

sub modify_all {

    my ( $self, @args ) = @_;

    # split the concatenated values of arguments (and retain undefined/space-only values)
    @args = map { [ defined($_) && $_ =~ m/(\s.*[^\s]|[^\s].*\s)/ ? split( / /, $_ ) : $_ ] } @args;
    my @ret_vals;

    # run the modifier on each arguments set
    foreach my $i ( 0 .. @{ $args[0] } - 1 ) {

        my @cur_ret_vals = $self->modify_single( map { $_->[$i] } @args );

        # append the return values
        if ( @ret_vals == 0 ) {
            @ret_vals = @cur_ret_vals;
        }
        else {
            for my $j ( 0 .. @cur_ret_vals - 1 ) {                
                $ret_vals[$j] .= $cur_ret_vals[$j] ? ' ' . $cur_ret_vals[$j] : '';
            }
        }
    }
    
    return @ret_vals;
};


sub modify_single {
    log_fatal 'Any AttributeModifier must override modify_single() or modify_all()!';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::AttributeModifier

=head1 DESCRIPTION

A base Moose role of text modifiers for blocks using L<Treex::Block::Write::LayerAttributes>. 
Any actual modifier implementation musts override the following methods/attributes:

=item C<modify_all()> or C<modify_single()>

A method which takes the textual value of attribute(s) and returns its/their modification(s).

If the given attribute value(s) is/are undefined, the method should return an undefined value, too; if 
the given attribute(s) is/are empty string(s), the result should also be empty string(s).

The first method gets all values together, if attributes with values for more nodes separated with spaces
are input. The second variant gets the values already split for each individual node by the default
C<modify_all()> method.

=item C<return_value_names>

This attribute must be an array reference containing the names of all the different values returned by
the modifier.    

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

