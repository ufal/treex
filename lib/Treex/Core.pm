package Treex::Core;
use Treex::Core::Document;
use Treex::Core::Node;
use Treex::Core::Bundle;
use Treex::Core::Scenario;

1;

__END__

=pod

=head1 NAME

Treex::Core - interface to linguistic structures and processing units in Treex

=head1 SYNOPSIS

 use Treex::Core;
 
 my $doc = Treex::Core::Document->new;
 
 my $bundle = $doc->create_bundle;
 my $zone   = $bundle->create_zone('en');
 my $atree  = $zone->create_atree;
 
 my $predicate = $atree->create_child({form=>'loves'});
 
 foreach my $arguments (qw(John Mary)) {
   my $child = $atree->create_child( { form=>$word } );
   $child->set_parent($predicate);
 }
 
 $doc->save('demo.treex');


=head1 DESCRIPTION

Treex::Core is a library of modules for processing linguistic data,
especially tree-shaped syntactic representations of natural language sentences.

Treex is tightly coupled with the tree editor


Treex::Core is language independent.


=head2 Data structure units

hlavni rozcestnik k treex core

=head3 Documents

Treex::Core::Document


=head3 Bundles

Treex::Core::Bundle

=head3 Trees and tree nodes

=head3 Attributes


=head2 Processing units

=head3 Block


=head3 Scenario

=head2 Support for visualizing Treex trees in TrEd





=head1 AUTHOR

Zdenek Zabokrtsky
Martin Popel
David Marecek

=head1 COPYRIGHT AND LICENSE

Copyright 2005-2011 by UFAL

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
