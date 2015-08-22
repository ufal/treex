package Treex::Block::Util::Find;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Util::Eval';

has on_error => (
    is            => 'ro',
    isa           => enum( [qw(fatal warn ignore)] ),
    default       => 'fatal',
    documentation => 'what to do on errors in the code for eval',
);

has expand_code => (
    is=> 'ro',
    isa => 'Bool',
    default => 1,
    documentation => 'Should "$." be expanded to "$this->" in all eval codes?',
);

has max_nodes_per_tree => (
    is=> 'ro',
    isa => 'Int',
    default => 0,
    documentation => 'Print at most N trees for each tree. Default 0 means unlimited.',
);


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
        my $this = $tree;
        if ( my $code = $self->_args->{"${layer}tree"} ) {
            $code =~ s/\$\./\$this->/g if $self->expand_code;
            if ( eval "my \$${layer}tree = \$tree; $code" ) {
                say $tree->get_address();
            }
            $self->_check_errors($code);
        }
        if ( my $code = $self->_args->{"${layer}node"} ) {
            my $nodes_found = 0;
            $code =~ s/\$\./\$this->/g if $self->expand_code;
            NODE:
            foreach my $node ( $tree->get_descendants() ) {
                $this = $node;
                if ( eval "my \$${layer}node = \$node; $code" ) {
                    say $node->get_address();                    
                    if ($self->max_nodes_per_tree){
                        $nodes_found++;
                        last NODE if $nodes_found >= $self->max_nodes_per_tree;
                    }
                }
                $self->_check_errors($code);
            }
        }
    }
    return;
}

sub _check_errors {
    my ($self, $code) = @_;
    return if !$@ || $self->on_error eq 'ignore';
    my $msg = "While evaluating '$code' got error: $@";
    log_fatal $msg if $self->on_error eq 'fatal';
    log_warn $msg;
    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Util::Find - Finding nodes based on criteria specified by parameters

=head1 SYNOPSIS

  # on the command line
  treex Util::Find anode='$anode->lemma eq "dog"' -- *.treex.gz
  treex Util::Find language=en tnode='$tnode->gram_gender eq "fem"' -- *.treex.gz

  # The same two commands even shorter
  treex Util::Find anode='$.lemma eq "dog"' -- *.treex.gz
  treex -Len Util::Find tnode='$.gram_gender eq "fem"' -- *.treex.gz

  # View a-trees with at least one coordination in ttred
  treex Util::Find anode='$.is_member' max_nodes_per_tree=1 -- *.treex.gz | ttred -l-

=head1 DESCRIPTION

The criteria specified in [atnp](node|tree) is an arbitrary Perl code.
If the code evaluates to a true value, the address of the node is printed
(in a format suitable for piping into C<ttred>).

You can use "$." instead of "$this->" where $this is the current tree/node.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
