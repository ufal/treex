package Treex::Block::Util::Eval;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has [
    qw( document bundle zone
        atree ttree ntree ptree
        anode tnode nnode pnode
        _args)
    ]
    => ( is => 'rw' );

has expand_code => (
    is=> 'ro',
    isa => 'Bool',
    default => 1,
    documentation => 'Should "$." be expanded to "$this->" in all eval codes?'
);

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    $arg_ref->{_atree}  = any { $arg_ref->{$_} } qw(atree anode);
    $arg_ref->{_ttree}  = any { $arg_ref->{$_} } qw(ttree tnode);
    $arg_ref->{_ntree}  = any { $arg_ref->{$_} } qw(ntree nnode);
    $arg_ref->{_ptree}  = any { $arg_ref->{$_} } qw(ptree pnode);
    $arg_ref->{_zone}   = any { $arg_ref->{$_} } qw(zone _atree _ttree _ntree _ptree);
    $arg_ref->{_bundle} = any { $arg_ref->{$_} } qw(bundle _zone);

    if ( !any { $arg_ref->{$_} } qw(doc document _bundle) ) {
        log_fatal "At least one of the following parameters must be non-empty:"
            . " document, bundle, zone, [atnp]tree, [atnp]node.";
    }
    if ($arg_ref->{doc}) {
        $self->set_document($arg_ref->{doc});
    }

    $self->_set_args($arg_ref);
    return;
}

sub expand_eval_code {
    my ($self, $to_eval) = @_;
    return "$to_eval;1;" if !$self->expand_code;
    $to_eval =~ s/\$\./\$this->/g;
    return "$to_eval;1;";
}

## no critic (ProhibitStringyEval) This block needs string evals
sub process_document {
    my ( $self, $document ) = @_;
    my $doc = $document;
    my $this = $document;
    if ( $self->document ) {
        my $to_eval = $self->expand_eval_code($self->document);
        eval($to_eval) or log_fatal("While evaluating '$to_eval' got error: $@");
    }

    if ( $self->_args->{_bundle} ) {
        my $bundleNo = 1;
        foreach my $bundle ( $document->get_bundles() ) {
            if ( !$self->select_bundles || $self->_is_bundle_selected->{$bundleNo} ) {
                $self->process_bundle($bundle, $bundleNo);
            }
            $bundleNo++;
        }
    }
    return;
}

sub process_bundle {
    my ( $self, $bundle, $bundleNo ) = @_;
    if ($self->report_progress){
        log_info "Processing bundle $bundleNo";
    }

    # Extract variables $document ($doc), so they can be used in eval code
    my $document = $bundle->get_document();
    my $doc      = $document;
    my $this     = $bundle;
    if ( $self->bundle ) {
        if ( !eval $self->expand_eval_code($self->bundle) ) {
            log_fatal "Eval error: $@";
        }
    }

    # quit if no parameters zone|?tree|?node
    return if !$self->_args->{_zone};
   
    foreach my $zone ( $self->get_selected_zones($bundle->get_all_zones()) ) {
        $self->process_zone($zone, $bundleNo);
    }
    return;
}

sub process_zone {
    my ( $self, $zone, $bundleNo ) = @_;

    # Extract variables $bundle, $document ($doc), so they can be used in eval code
    my $bundle   = $zone->get_bundle();
    my $document = $bundle->get_document();
    my $doc      = $document;
    my $this     = $zone;
    if ( $self->zone ) {
        if ( !eval $self->expand_eval_code($self->zone) ) {
            log_fatal "Eval error: $@";
        }
    }

    foreach my $layer (qw(a t n p)) {
        next if !$zone->has_tree($layer);
        my $tree = $zone->get_tree($layer);
        $this = $tree;
        if ( my $code = $self->_args->{"${layer}tree"} ) {
            if ( !eval $self->expand_eval_code("my \$${layer}tree = \$tree; $code") ) {
                log_fatal "Eval error: $@";
            }
        }
        if ( my $code = $self->_args->{"${layer}node"} ) {
            foreach my $node ( $tree->get_descendants({ordered => ($layer ne 'p')}) ) {
                $this = $node;
                if ( !eval $self->expand_eval_code("my \$${layer}node = \$node; $code;") ) {
                    log_fatal "Eval error: $@";
                }
            }
        }
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::Util::Eval - Special block for evaluating code given by parameters.

=head1 SYNOPSIS

  # on the command line
  treex Util::Eval document='print $document->full_filename' -- *.treex
  treex Util::Eval language=en anode='print $anode->lemma."\n"' -- *.treex

  # The same two commands even shorter
  treex Util::Eval doc='print $.full_filename' -- *.treex
  treex -Len Util::Eval anode='say $.lemma' -- *.treex

  # other examples of parameters
  language=en,cs zone='say $.language, "\t", $.sentence'
  language=all ttree='say $.language, "\t", scalar $.get_children()'

=head1 DESCRIPTION

Evaluate an arbitrary Perl code for each document/bundle/zone/tree/node (according to which parameter 
is given). The corresponding object is accessible through a variable of the same name or C<$this>.

More shortcuts:
You can use doc= instead of document=.
You can use "$." instead of "$this->" where $this is the current doc/bundle/zone/tree/node.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
