package Treex::Core::Node::Interset;
use Moose::Role;

# with Moose >= 2.00, this must be present also in roles
use MooseX::SemiAffordanceAccessor;
use Treex::Core::Log;
use List::Util qw(first);    # TODO: this wouldn't be needed if there was Treex::Core::Common for roles
use tagset::common;



#------------------------------------------------------------------------------
# Takes the Interset feature structure as a hash reference (as output by an
# Interset decode() function). For all hash keys that are known Interset
# feature names, sets the corresponding iset attribute.
#
# If the first argument is not a hash reference, the list of arguments is
# considered a list of features and values. Usage examples:
#
#    set_iset(\%feature_structure);
#    set_iset('pos', 'noun');
#    set_iset('pos' => 'noun', 'gender' => 'masc', 'number' => 'sing');
#------------------------------------------------------------------------------
sub set_iset
{
    my $self = shift;
    my %f;
    if(ref($_[0]) eq 'HASH')
    {
        %f = %{$_[0]};
    }
    else
    {
        %f = @_;
    }
    foreach my $feature (@tagset::common::known_features)
    {
        if(exists($f{$feature}))
        {
            if(ref($f{$feature}) eq 'ARRAY')
            {
                ###!!! PROBLEM: disjunctions of values are not defined in the PML schema.
                $self->set_attr("iset/$feature", join('|', sort(@{$f{$feature}})));
            }
            else
            {
                $self->set_attr("iset/$feature", $f{$feature});
            }
        }
    }
}



#------------------------------------------------------------------------------
# Gets the value of an Interset feature. Makes sure that the result is never
# undefined so the use/strict/warnings creature keeps quiet.
###!!! It could return undef if we ask for the value of an unknown feature.
#------------------------------------------------------------------------------
sub get_iset
{
    my $self = shift;
    my $feature = shift;
    my $value = $self->get_attr("iset/$feature");
    $value = '' if(!defined($value));
    return $value;
}



#------------------------------------------------------------------------------
# Tests multiple Interset features simultaneously. Input is a list of feature-
# value pairs, return value is 1 if the node matches all these values. This
# function is an abbreviation for a series of get_iset() calls in an if
# statement:
#
# if(match_iset($node, 'pos' => 'noun', 'gender' => 'masc')) { ... }
#------------------------------------------------------------------------------
sub match_iset
{
    my $self = shift;
    my @req = @_;
    for(my $i = 0; $i<=$#req; $i += 2)
    {
        my $value = $self->get_iset($req[$i]);
        my $comp = $req[$i+1] =~ s/^\!// ? 'ne' : $req[$i+1] =~ s/^\~// ? 're' : 'eq';
        if($comp eq 'eq' && $value ne $req[$i+1] ||
           $comp eq 'ne' && $value eq $req[$i+1] ||
           $comp eq 're' && $value !~ m/$req[$i+1]/)
        {
            return 0;
        }
    }
    return 1;
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::Node::Interset

=head1 DESCRIPTION

Moose role for nodes that have the Interset feature structure.

=head1 ATTRIBUTES

=over

=item iset/*

Attributes corresponding to Interset features.

=back

=head1 METHODS

=head2 Access to Interset features

=over

=item my $boolean = $node->match_iset($node, 'pos' => 'noun', 'gender' => '!masc', ...);

Do the feature values of this node match the specification?
(Values of other features do not matter.)
A value preceded by exclamation mark is tested on string inequality.
Other values are tested on string equality.

=back


=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
