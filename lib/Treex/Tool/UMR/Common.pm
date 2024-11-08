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
our @EXPORT_OK = qw{ get_corresponding_unode is_coord expand_coord maybe_set };

sub get_corresponding_unode {
    my ($any_unode, $tnode, $uroot) = @_;
    my @uroots = $uroot
        // map $_->get_tree($any_unode->language, 'u'),
           $any_unode->get_document->get_bundles;
    my ($u) = grep $tnode == ($_->get_tnode // 0),
        map $_->descendants, @uroots;
    return $u
}

sub is_coord {
    my ($unode) = @_;
    return $unode->concept =~ /^(?:(?:but|contrast|have-cause)-91
                                   |and|contra|consecutive
                                   |exclusive-disjunctive|interval)$/x
            ? 1 : 0
}

sub expand_coord {
    my ($unode) = @_;
    return $unode unless is_coord($unode);

    my $expansion_re = $unode->concept =~ /-91$/ ? qr/^ARG[1-9]/ : qr/^op[1-9]/;
    my @expansion = map expand_coord($_),
                    grep $_->functor =~ /$expansion_re/,
                    $unode->children;
    return @expansion
}

{   my %GRAM = (person => {
                    1     => '1st',
                    2     => '2nd',
                    3     => '3rd',
                    inher => 'Inher'},
                number => {
                    sg    => 'singular',
                    S     => 'singular',
                    pl    => 'plural',
                    P     => 'plural',
                    inher => 'inher'});
    my %IMPLEMENTATION = (person => {gram => 'gram_person',
                                     tag  => '^.{7}([123])',
                                     attr => 'entity_refperson'},
                          number => {gram => 'gram_number',
                                     tag  => '^.{3}([SP])',
                                     attr => 'entity_refnumber'});
    sub maybe_set {
        my ($gram, $unode, $orig_node) = @_;
        my $get_attr = $IMPLEMENTATION{$gram}{attr};
        return if $unode->$get_attr;

        my $set_attr = "set_$IMPLEMENTATION{$gram}{attr}";
        if ($orig_node->isa('Treex::Core::Node::T')) {

            my $value = $orig_node->${ \$IMPLEMENTATION{$gram}{gram} };
            if (! $value) {
                if (my $anode = $orig_node->get_lex_anode) {
                    ($value) = $anode->tag =~ $IMPLEMENTATION{$gram}{tag};
                }
            }
            warn("$unode->{id} $gram $GRAM{$gram}{$value}"),
            $unode->$set_attr($GRAM{$gram}{$value}) if $value;

        } else {
            $unode->$set_attr($orig_node->$get_attr);
        }
        return
    }
}

__PACKAGE__
