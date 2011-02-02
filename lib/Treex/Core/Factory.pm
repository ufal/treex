package Treex::Core::Factory;
# Until we solve the error:
# Deep recursion on anonymous subroutine at /mnt/h/repl/perl_repo/share/perl/5.8.8/Treex/PML/Factory.pm line 65.
0;
__END__

use strict;
use warnings;

use base qw(Treex::PML::StandardFactory);

use Treex::Core::Node;
use Treex::Core::Bundle;
use Treex::Core::Document;
use Treex::Core::Node::A;
use Treex::Core::Node::T;
use Treex::Core::Node::N;

sub createDocument {
    my $self = shift;
    return Treex::Core::Document->new();
}


my @backends = Treex::PML::ImportBackends('PMLBackend');
Treex::PML::AddResourcePath($ENV{"TMT_ROOT"} . "/pml_schemas/");

# dirty: global variable because of indexing nodes from a loaded file
# (temporal solution, as api for accessing all generic trees in a bundle is missing so far)
my $_collect_created_nodes;

sub createDocumentFromFile {
    my $self = shift;
    my $filename = shift;
    my $params_rf = shift || {};

    $params_rf->{backends} = \@backends;

    my $pml_doc = $self->SUPER::createDocumentFromFile($filename,$params_rf,@_);
    my $doc = Treex::Core::Document->new(pml_doc => $pml_doc);

    $doc->_set_index({});

    foreach my $bundle ($doc->get_bundles) {

        bless $bundle, 'Treex::Core::Bundle';

        foreach my $tree ($bundle->get_all_trees) {
            $tree->type->get_structure_name =~ /(\S)-(root|node)/
                or log_fatal "Unexpected member in zone structure: ".$tree->type;
            my $layer = uc($1);
            foreach my $node ($tree, $tree->descendants) { # must call Treex::PML::Node API
                bless $node, "Treex::Core::Node::$layer";
                $doc->index_node_by_id($node->get_id,$node);
            }
        }
        $bundle->_set_document($doc);
    }

    return $doc;
}


sub createTypedNode {
  my $self = shift;
  my $node;

  if (@_>1 and !ref($_[0]) and does($_[1],'Treex::PML::Schema')) {
    my $type = shift;
    print "Type: $type\n";
    my $schema = shift;
    $node = $self->createNode(@_);
    $node->set_type_by_name($schema,$type);
  }

  else {
    my $decl = shift;

    my $pml_type = $decl->{qw(-path)};
    $pml_type =~ s/\!//;
    if ($pml_type eq "bundle.type") {
        $node = Treex::Core::Bundle->new(@_);
    }
    else {
        $node = Treex::Core::Node->new(@_);
    }


    $node->set_type($decl);
  }

#  if ($_collect_created_nodes) {
#      push @_created_nodes, $node;
#  }

  return $node;
}



1;

__END__

=head1 NAME

Treex::Core::Factory


=head1 SYNOPSIS

 use Treex::Core::Scenario;
 ??? ??? ??? ???



=head1 DESCRIPTION

Factory for creating document objects (to avoid calling constructors).


=head1 METHODS

=head2 Constructor

=over 4

=item my $doc = Treex::Core::Factory->createDocument;

Creates an empty Treex document.

=item my $doc = Treex::Core::Factory->createDocumentFromFile($filename);

Constructor argument is a reference to a hash containing options. Option 'blocks' specifies
the reference to the array of names of blocks which are to be executed (in the specified order)
when the scenario is applied on a Treex::Core::Document object.

=item my $doc = Treex::Core::Factory->createTypedNode;

internal

=back


=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright 2010 Zdenek Zabokrtsky
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

