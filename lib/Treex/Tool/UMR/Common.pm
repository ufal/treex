package Treex::Tool::UMR::Common;

=head1 NAME

 Treex::Tool::UMR::Common

=head1 DESCRIPTION

Common functions for various UMR processing packages.

=head1 FUNCTIONS

=over 4

=item get_corresponding_unode($unode, $tnode, $uroot ?)

If $uroot is not given, use $unode to find the $uroot, than search all
its descendants for the one that references the $tnode.

=back

=cut

use warnings;
use strict;

use Exporter qw{ import };
our @EXPORT_OK = qw{ get_corresponding_unode };

sub get_corresponding_unode {
    my ($any_unode, $tnode, $uroot) = @_;
    my @uroots = $uroot
        // map $_->get_tree($any_unode->language, 'u'),
           $any_unode->get_document->get_bundles;
    my ($u) = grep $tnode == ($_->get_tnode // 0),
        map $_->descendants, @uroots;
    return $u
}

__PACKAGE__
