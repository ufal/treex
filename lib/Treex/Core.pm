package Treex::Core;

use strict;
use warnings;
use Treex::Core::Document;
use Treex::Core::Node;
use Treex::Core::Bundle;
use Treex::Core::Scenario;

1;

__END__

=pod

=encoding utf8

=head1 NAME

Treex::Core - interface to linguistic structures and processing units in Treex

=head1 SYNOPSIS

 use Treex::Core;
 
 my $doc = Treex::Core::Document->new;
 
 my $bundle = $doc->create_bundle;
 my $zone   = $bundle->create_zone('en');
 my $atree  = $zone->create_atree;
 
 my $predicate = $atree->create_child({form=>'loves'});
 
 foreach my $argument (qw(John Mary)) {
   my $child = $atree->create_child( { form=>$argument } );
   $child->set_parent($predicate);
 }
 
 $doc->save('demo.treex');


=head1 DESCRIPTION

C<Treex::Core> is a library of modules for processing linguistic data,
especially tree-shaped syntactic representations of natural language
sentences, both for language analysis and synthesis purposes.

C<Treex::Core> is meant to be as language universal as possible.
It makes only a few assumptions: the language's written form must be
representable by Unicode characters, and it should be possible to segment
texts in such language into sentences (or sentence-like units) and words
(or word-like units).

C<Treex::Core> is tightly coupled with the tree editor TrEd, which
makes browsing the linguistic data structures very comfortable.

C<Treex::Core> uses TrEd's L<Treex::PML> for the memory
representation, as well as for storing the data into *.treex files, using
the XML-based Prague Markup Language.


=head2 Zones parametrized by language codes and selectors

Treex documents can contain parallel texts in two or more languages,
as well as alternative linguistic representations (such as two
dependency parses of a same sentence, resulting from different parsers).
Such contents of the same type are separated by introducing zones.

Zones (classes derived from L<Treex::Core::Zone>) are 
parametrized by language ISO codes, and optionally also by so called 
selectors. Selector can be any string identifying the source or purpose of the 
given piece of data. It can distinguish e.g. reference translation from 
machine-translated text, or the most probable parse of a given sentence from 
the second most probable parse. In Treex data structures, zones are used at 
two levels:

- L<Treex::Core::DocZone> - allows to have multiple texts
  stored in the same document

- L<Treex::Core::BundleZone> - allows to have multiple
  sentences and their representations in each bundle.

As for Treex processing units (scenarios and blocks, see below), each
processing unit either limits itself to a certain zone, or it can be
zone-parametrized (especially in the case of language-universal blocks).

=head2 Data structure units

In Treex, linguistic representations of running texts are organized
in the following hierarchy:

=head3 Documents

The smallest independently storable unit is a document
(L<Treex::Core::Document>).

Technically, each document consists of a set of document zones, and of a
sequence of bundles.

=head3 Document zone

A document can contain one ore more zone 
(L<Treex::Core::DocZone>), each of them containing a text.

=head3 Bundle

A bundle (L<Treex::Core::Bundle>) corresponds to a 
sentence (or a tuple of parallel or alternative sentences) and all its (or 
their) linguistic analyses.

Technically, a bundle contains a set of bundle zones.

=head3 Bundle zone

Bundle zone (L<Treex::Core::Bundle>) contains one sentence 
and at most one its linguistic analysis for each layer of analysis. The 
following layers are currently distinguished:

* a-layer - analytical layer (surface syntax dependency layer) merged with the
  morphological layer, as defined in the Prague Dependency Treebank.

* t-layer - tectogrammatical layer (deep-syntactic dependency)

* p-layer - phrase-structure layer

* n-layer - named entity layer

Each layer representation has a form of a tree, represented by the tree's root node.

=head3 Node

Each node has a parent (unless it is the root) and a set of predefined 
attributes, depending on the layer it belongs to. There is an abstract class 
L<Treex::Core::Node> defining the functionality which is 
common to all types of trees (such as functions for accessing node's parent or 
children). Functionality specific for the individual linguistic layers is 
implemented in the derived classes:

* L<Treex::Core::Node::A>

* L<Treex::Core::Node::T>

* L<Treex::Core::Node::P>

* L<Treex::Core::Node::N>

=head3 Attributes

Nodes contain attribute-value pairs. Some attributes are universal (such as 
identifier), but most of them are specific for a certain layer. Even if node 
instances are regular Moose objects (i.e., blessed hashes), node's attributes 
should be accessed exclusively via predefined accessors.

Attribute values can be plain or further structured using PML data types (e.g. 
sequences), according to the PML schema.


=head2 Processing units

=head3 Block

Blocks (descendants of L<Treex::Core::Block>) are the 
smallest processing units applicable on Treex documents.

=head3 Scenario

Scenarios (instances of L<Treex::Core::Scenario>) are 
sequences of blocks. Blocks from a scenario are applied on a document one 
after another.

=head2 Support for visualizing Treex trees in TrEd

C<Treex::Core> also contains a TrEd extension for browsing .treex files.
The extension itself is only a thin wrapper for the viewing functionality
implemented in L<Treex::Core::TredView>.


=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
