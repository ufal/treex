package Treex::Block::Util::Find;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Util::Eval';

has [
    qw(document bundle zone
        atree ttree ntree ptree
        anode tnode nnode pnode
        languages selectors
        _args)
    ]
    => ( is => 'rw' );

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    $arg_ref->{_atree}  = any { $arg_ref->{$_} } qw(atree anode);
    $arg_ref->{_ttree}  = any { $arg_ref->{$_} } qw(ttree tnode);
    $arg_ref->{_ntree}  = any { $arg_ref->{$_} } qw(ntree nnode);
    $arg_ref->{_ptree}  = any { $arg_ref->{$_} } qw(ptree pnode);
    $arg_ref->{_zone}   = any { $arg_ref->{$_} } qw(zone _atree _ttree _ntree _ptree);
    $arg_ref->{_bundle} = any { $arg_ref->{$_} } qw(bundle _zone);

    if ( !any { $arg_ref->{$_} } qw(document _bundle) ) {
        log_fatal "At least one of the following parameters must be non-empty:"
            . " document, bundle, zone, [atnp]tree, [atnp]node.";
    }

    if ( $arg_ref->{_zone} && !any { $arg_ref->{$_} } qw(languages language) ) {
        log_fatal "You must specify at least one of the parameters:"
            . " languages, language (or just document or bundle).";
    }
    if ( !$self->languages ) { $self->set_languages( $self->language ); }
    if ( !$self->selectors ) { $self->set_selectors( $self->selector ); }

    $self->_set_args($arg_ref);
    return;
}

## no critic (ProhibitStringyEval) This block needs string evals
sub process_zone {
    my ( $self, $zone ) = @_;

    # Extract variables $bundle, $document ($doc), so they can be used in eval code
    my $bundle   = $zone->get_bundle();
    my $document = $bundle->get_document();
    my $doc      = $document;

    foreach my $layer (qw(a t n p)) {
        next if !$zone->has_tree($layer);
        my $tree = $zone->get_tree($layer);
        if ( my $code = $self->_args->{"${layer}tree"} ) {
            if ( eval "my \$${layer}tree = \$tree; $code" ) {
                say $tree->get_address();
            }
        }
        if ( my $code = $self->_args->{"${layer}node"} ) {
            foreach my $node ( $tree->get_descendants() ) {
                if ( eval "my \$${layer}node = \$node; $code" ) {
                    say $node->get_address();
                }
            }
        }
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::Util::Find - Finding nodes based on criteria specified by parameters

=head1 SYNOPSIS

  # on the command line
  treex Util::Eval anode='$anode->lemma eq "dog"' -- *.treex
  treex Util::Eval language=en tnode='$tnode->gram_gender eq "fem"' -- *.treex


=head1 DESCRIPTION

The criteria specified in [atnp](node|tree) is an arbitrary Perl code.
If the code evaluates to a true value, the address of the node is printed
(in a format suitable for piping into C<ttred>).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
