package Treex::Block::Treelets::ExtractVW;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

use TranslationModel::Static::Model;

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for all models'
);

has static_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tlemma_czeng09.static.pls.slurp.gz',
);

my $static;

sub load_model {
    my ( $self, $model, $filename ) = @_;
    my $path = $self->model_dir . '/' . $filename;
    $model->load( Treex::Core::Resource::require_file_from_share($path) );
    return $model;
}

sub process_start {
    my ($self) = @_;
    $self->SUPER::process_start();
    $static = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model );
    return;
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;
    my ($en_tnodes_rf, $ali_types_rf) = $cs_tnode->get_aligned_nodes();
    for my $i (0 .. $#{$en_tnodes_rf}) {
        my $types = $ali_types_rf->[$i];
        if ($types =~ /int|tali/){
            $self->print_tnode_features($cs_tnode, $en_tnodes_rf->[$i], $types);
        }
    }
    return;
}
sub print_tnode_features {
    my ( $self, $cs_tnode, $en_tnode, $ali_types ) = @_;
    my $cs_anode = $cs_tnode->get_lex_anode or return;

    #return if $en_tnode->functor =~ /CONJ|DISJ|ADVS|APPS/;
    my $en_tlemma = $self->lemma($en_tnode);    
    my $cs_tlemma = $self->lemmapos($cs_tnode);
    return if $en_tlemma !~ /\p{IsL}/ || $cs_tlemma !~ /\p{IsL}/;
    
    # Do not train on instances where the correct translation is not listed in the Static model.
    my $submodel = $static->_submodels->{$en_tlemma};
    return if !$submodel || !$submodel->{$cs_tlemma};
    
    my ($en_tparent) = $en_tnode->get_eparents( { or_topological => 1 } );
    my $feats = 'F=' . $en_tnode->formeme
              . ' P=' . $self->lemma($en_tparent);
    $feats .= ' n=' . $en_tnode->gram_number if $en_tnode->gram_number;

    foreach my $child ($en_tnode->get_echildren( { or_topological => 1 } )){
        $feats .= ' CL=' . $self->lemma($child);
        $feats .= ' CF=' . $child->formeme;
    }
    $feats =~ s/:/;/g; # VW format does not allow ":"
    $en_tlemma =~ s/:/;/g;
    $cs_tlemma =~ s/:/;/g;

    my ($i);
    foreach my $variant (keys %{$submodel}){
        $i++;
        $variant =~ s/:/;/g;
        my $cost = $variant eq $cs_tlemma ? 0 : 1;
        print { $self->_file_handle() } "$i:$cost |S=$en_tlemma,T=$variant $feats\n";
    }
    print { $self->_file_handle() } "\n";
    return;
}

# Hack to include coarse-grained PoS tag for Czech lemma.
# $tnode->get_attr('mlayer_pos') is not filled in CzEng
sub lemmapos {
    my ($self, $tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;
    my $anode = $tnode->get_lex_anode or return $lemma;
    my ($pos) = ( $anode->tag =~ /^(.)/ );
    return $lemma if !defined $pos;
    return "$lemma#$pos";
}

sub lemma {
    my ($self, $tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;
    return $lemma;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Treelets::ExtractVW - extract translation training vectors for VW

=head1 DESCRIPTION

Extract translation training vectors for Vowbal Wabbit in the csoaa_ldf=mc format.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
