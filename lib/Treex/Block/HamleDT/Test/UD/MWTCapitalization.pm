package Treex::Block::HamleDT::Test::UD::MWTCapitalization;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        # Is this node part of a multi-word token?
        if(exists($node->wild()->{fused}))
        {
            my $pform = $node->form();
            my $fform = $node->wild()->{fused_form};
            if($node->wild()->{fused} eq 'start')
            {
                if(is_uppercase($fform) && !is_uppercase($pform) ||
                   is_lowercase($fform) && !is_lowercase($pform) ||
                   is_capitalized($fform) && !is_capitalized($pform))
                {
                    $self->complain($node, "Inconsistent capitalization: fused $fform, first part $pform");
                }
            }
            else
            {
                if(is_uppercase($fform) && !is_uppercase($pform) ||
                   is_lowercase($fform) && !is_lowercase($pform) ||
                   is_capitalized($fform) && !is_lowercase($pform))
                {
                    $self->complain($node, "Inconsistent capitalization: fused $fform, non-first part $pform");
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Checks whether a string is all-uppercase.
#------------------------------------------------------------------------------
sub is_uppercase
{
    my $string = shift;
    return $string eq uc($string);
}



#------------------------------------------------------------------------------
# Checks whether a string is all-lowercase.
#------------------------------------------------------------------------------
sub is_lowercase
{
    my $string = shift;
    return $string eq lc($string);
}



#------------------------------------------------------------------------------
# Checks whether a string is capitalized.
#------------------------------------------------------------------------------
sub is_capitalized
{
    my $string = shift;
    return 0 if(length($string)==0);
    $string =~ m/^(.)(.*)$/;
    my $head = $1;
    my $tail = $2;
    return is_uppercase($head) && !is_uppercase($tail);
}



1;

=over

=item Treex::Block::HamleDT::Test::UD::MWTCapitalization

If the writing system distinguishes uppercase and lowercase, they should be used
consistently in the form of a multi-word token and in the forms of its parts.
If the MWT is all-lowercase or all-uppercase, the same should hold for the
individual words (even though the MWT is not a simple concatenation of the words).
If the MWT is capitalized (or more generally: it is not all-uppercase but the
first letter is uppercase) then the first word should be capitalized and the
remaining words should be all-lowercase.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
