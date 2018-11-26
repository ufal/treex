package Treex::Block::W2W::AddNodeIdPrefix;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'prefix' =>
(
    is      => 'ro',
    isa     => 'Str',
    default => ''
);

has 'scsubst' =>
(
    is      => 'ro',
    isa     => 'Bool',
    default => undef,
    documentation => 'Replace special characters in node id for PML-TQ.'
);



sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $id = $node->id();
    my $prefix = $self->prefix();
    $id = $prefix.$id;
    # For PML-TQ, we may want to simplify the repertory of special characters in node ids
    # (especially the slashes ('/') used to pose problems for node highlighting in SVG).
    # According to specification, an id in PML must be of the type NCName (http://www.datypic.com/sc/xsd/t-xsd_NCName.html).
    # It must start with either a letter or underscore (_) and may contain only
    # letters, digits, underscores (_), hyphens (-), and periods (.).
    if ($self->scsubst())
    {
        # We are going to use hyphens as separators of id segments. Replace any pre-existing hyphens by periods.
        $id =~ s/-+/./g;
        # Slashes, if any, separate id segments. Replace them by hyphens.
        $id =~ s:/+:-:g;
        # The first underscore should be treated as a segment separator too.
        # It comes from the prefix and it separates language code from treebank code.
        $id =~ s/_/-/;
        # Reduce spaces and underscores.
        $id =~ s/[_\s]+/_/g;
        # Reduce other disallowed symbols.
        #$id =~ s/[\.:;,\+\*\&%=\$\@~\#!\?\(\)\[\]\{\}<>\^\"\'\`\\\|]+/./g;
        $id =~ s/[^-_\.\pL\pN]+/./g;
    }
    $node->set_id($id);
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::AddNodeIdPrefix

=head1 DESCRIPTION

Adds a prefix to the id of every node. It can be a subcorpus identifier.
Then we can index a collection of corpora as one corpus.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
