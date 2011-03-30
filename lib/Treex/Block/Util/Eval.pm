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

sub process_document {
    my ( $self, $document ) = @_;
    eval $self->document if $self->document;

    if ( $self->_args->{_bundle} ) {
        foreach my $bundle ( $document->get_bundles() ) {
            $self->process_bundle($bundle);
        }
    }
    return;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    eval $self->bundle if $self->bundle;

    # quit if no parameters zone|?tree|?node
    return if !$self->_args->{_zone};

    my %do_lang = map { $_ => 1 } split /,/, $self->languages;
    my %do_sele = map { $_ => 1 } split /,/, $self->selectors;
    $do_sele{''} = 1 if $self->selectors eq '';    # split /,/, ''; #returns empty list

    foreach my $zone ( $bundle->get_all_zones() ) {
        if ( $do_lang{ $zone->language } && $do_sele{ $zone->selector } ) {
            $self->process_zone($zone);
        }
    }

    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    eval $self->zone if $self->zone;

    foreach my $layer (qw(a t n p)) {
        next if !$zone->has_tree($layer);
        my $tree = $zone->get_tree($layer);
        if ( my $code = $self->_args->{"${layer}tree"} ) {
            eval "my \$${layer}tree = \$tree; $code";
        }
        if ( my $code = $self->_args->{"${layer}node"} ) {
            foreach my $node ( $tree->get_descendants() ) {
                eval "my \$${layer}node = \$node; $code";
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



=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
