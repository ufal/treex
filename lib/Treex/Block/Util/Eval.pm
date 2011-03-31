package Treex::Block::Util::Eval;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

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
        log_fatal "You must specify at least one of the parameters:"
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
sub process_document {
    my ( $self, $document ) = @_;
    if ( $self->document ) {
        if ( !eval $self->document . ';1;' ) {
            log_fatal "Eval error: $@";
        }
    }

    if ( $self->_args->{_bundle} ) {
        foreach my $bundle ( $document->get_bundles() ) {
            $self->process_bundle($bundle);
        }
    }
    return;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    if ( $self->bundle ) {
        if ( !eval $self->bundle . ';1;' ) {
            log_fatal "Eval error: $@";
        }
    }

    # quit if no parameters zone|?tree|?node
    return if !$self->_args->{_zone};

    my %do_lang = map { $_ => 1 } split /,/, $self->languages;
    my %do_sele = map { $_ => 1 } split /,/, $self->selectors;

    # split /,/, ''; #returns empty list
    if ( $self->selectors eq '' ) {
        $do_sele{''} = 1;
    }

    foreach my $zone ( $bundle->get_all_zones() ) {
        if ( $do_lang{ $zone->language } && $do_sele{ $zone->selector } ) {
            $self->process_zone($zone);
        }
    }

    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    if ( $self->zone ) {
        if ( !eval $self->zone . ';1;' ) {
            log_fatal "Eval error: $@";
        }
    }

    foreach my $layer (qw(a t n p)) {
        next if !$zone->has_tree($layer);
        my $tree = $zone->get_tree($layer);
        if ( my $code = $self->_args->{"${layer}tree"} ) {
            if ( !eval "my \$${layer}tree = \$tree; $code;1;" ) {
                log_fatal "Eval error: $@";
            }
        }
        if ( my $code = $self->_args->{"${layer}node"} ) {
            foreach my $node ( $tree->get_descendants() ) {
                if ( !eval "my \$${layer}node = \$node; $code;1;" ) {
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
  treex Util::Eval language=en anode='print $anode->lemma' -- *.treex

  # other examples of parameters
  languages=en,cs zone='print $zone->language, "\t", $zone->sentence'
  languages=all ttree='print $ttree->language, "\t", scalar $ttree->get_children'

=head1 DESCRIPTION



=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
