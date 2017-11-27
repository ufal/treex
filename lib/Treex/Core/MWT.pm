package Treex::Core::MWT;

use Moose;
use Treex::Core::Common;
use Treex::PML::List;


has form => (
    is => 'rw',
    isa => 'Str',
    documentation => 'wordform of the whole multiword token',
);

has _words => (
    is => 'ro',
    # TODO: we need a subclass of Treex::PML::List
    # which weakens all the references to the values it contains
    # (so there are no circular references and memory leaks)
    # and possibly it also checks if the nodes
    # are from the same tree with consecutive ords
    isa => 'Treex::PML::List',
    builder => sub {Treex::PML::List->new()},
);

# TODO: allow calling new({words=>\@words, fused_form=>$fused_form});
#sub BUILD {my ($self, $arg_ref) = @_;}

sub words {
    my ($self) = @_;
    return wantarray ? $self->_words->values() : $self->_words;
}

# Martin Popel:
# Pro ostatní atributy, cos navrhoval (lemma, tag, iset),
# bych nezaváděl zvláštní metody do té doby než:
# a) se ukáže, že se to používá na hodně místech,
# b) se ukáže, že implementace je netriviální.
# Do té doby jde používat:
# my $fused_lemma = join '' map {$_->lemma} $mwt->words;
# my $fused_iset = Lingua::Interset::FeatureStructure->new()
# $fused_iset->set_hash(map {%{$_->iset->get_hash()}} $mwt->words);

1;



=for Pod::Coverage BUILD


=encoding utf-8

=head1 NAME

Treex::Core::MWT - multi-word token (Universal Dependencies)

=head1 DESCRIPTION

This class represents a multi-word token as defined in the Universal
Dependencies: one surface token that corresponds to several syntactically
independent words (Treex nodes).

Instances of Treex::Core::MWT are created from Treex::Core::Node when a node
shall become part of a multiword token.

    my $mwt = $root->create_multiword_token(\@nodes, $fused_form);

The method can be called on any node of the tree and it takes reference to the
list of nodes of the same tree that are members of the multiword token.

Ještě se ale bude muset do metody remove() přidat test na to,
zda ten uzel není součástí nějakého MWT,
a pokud ano, tak ho zřejmě smazat i z toho MWT
(případně na to zavést parametr, kterým by šlo nastavit,
že se zařve fatal error).
my $mwt = $node->get_multiword_token();
return if !defined $mwt;


=== Editace ===

Metoda Treex::Core::MWT::words() bude tedy vracet
- v list contextu množinu slov toho tokenu
- ve scalar contextu objekt typu Treex::PML::List, který má metody
  append(), values(), empty() a mnoho dalších.
- Možná bych mohl použít potomk Treex::PML::List,
  který by při append() (a dalších metodách, co přidávají uzly),
  kontroloval, zda ty uzly mají po sobě jdoucí ordy.
- Podobný mechanismus (Treex::PML::List) bych chtěl využít i jinde v Treexu.
  Určitě v těch nových koordinacích (https://wiki.ufal.ms.mff.cuni.cz/treex:coordinations)
  a klauzích a alignovaných uzlech a seznamech koreferencí a aux.rf.

Martin

=head1 METHODS

=head2 Construction

=over 4

=item  my $new_node = $existing_node->create_child({lemma=>'house', tag=>'NN' });

Creates a new node as a child of an existing node. Some of its attribute
can be filled. Direct calls of node constructors (C<< ->new >>) should be avoided.


=back



=head2 Access to the containers

=over 4

=item my $bundle = $node->get_bundle();

Returns the L<Treex::Core::Bundle> object in which the node's tree is contained.

=item my $document = $node->get_document();

Returns the L<Treex::Core::Document> object in which the node's tree is contained.

=back



=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2017 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
