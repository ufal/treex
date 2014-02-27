package Treex::Block::Treelets::ExtractVW;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

use TranslationModel::Static::Model;

has shared_format => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'VW with csoaa_ldf supports a compact format for shared features'
);

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
    my $en_tlemma = lemma($en_tnode);    
    my $cs_tlemma = lemmapos($cs_tnode);
    return if $en_tlemma !~ /\p{IsL}/ || $cs_tlemma !~ /\p{IsL}/;
    
    # Do not train on instances where the correct translation is not listed in the Static model.
    my $submodel = $static->_submodels->{$en_tlemma};
    return if !$submodel || !$submodel->{$cs_tlemma};
    
    # Features from this node
    my $feats = join '',
        add($en_tnode, 'f', 'formeme'),
        add($en_tnode, 'num', 'gram/number'),
        add($en_tnode, 'voi', 'gram/voice'),
        add($en_tnode, 'neg', 'gram/negation'),
        add($en_tnode, 'ten', 'gram/tense'),
        add($en_tnode, 'per', 'gram/person'),
        add($en_tnode, 'deg', 'gram/degcmp'),
        add($en_tnode, 'pos', 'gram/sempos'),
        add($en_tnode, 'mem', 'is_member'),
        add($en_tnode, 'art', '_article'),
        add($en_tnode, 'ent', '_ne_type'),
        ;

    # Features from its parent
    my ($en_tparent) = $en_tnode->get_eparents( { or_topological => 1 } );
    if (!$en_tparent->is_root){
        $feats .= join '',
        ' fPl=' . $en_tnode->formeme . '_' . lemma_or_tag($en_tparent),
        add($en_tparent, 'Pnum', 'gram/number'),
        add($en_tparent, 'Pvoi', 'gram/voice'),
        add($en_tparent, 'Pneg', 'gram/negation'),
        add($en_tparent, 'Pten', 'gram/tense'),
        add($en_tparent, 'Pper', 'gram/person'),
        add($en_tparent, 'Pdeg', 'gram/degcmp'),
        add($en_tparent, 'Ppos', 'gram/sempos'),
        add($en_tparent, 'Pmem', 'is_member'),
        add($en_tparent, 'Part', '_article'),
        add($en_tparent, 'Pent', '_ne_type'),
        ;
    }

#     my ($en_tparent) = $en_tnode->get_eparents( { or_topological => 1 } );
#     my $feats = 'f=' . $en_tnode->formeme
#               . ' fPl=' . $en_tnode->formeme . '_' . lemma_or_tag($en_tparent);
#     $feats .= ' n=' . $en_tnode->gram_number if $en_tnode->gram_number;

    # Features from its children
    foreach my $child ($en_tnode->get_echildren( { or_topological => 1 } )){
        if (my $achild = $child->get_lex_anode) {
            $feats .= ' Ct=' . $achild->tag;
            $feats .= ' Cc=' . $achild->form =~ /^\p{IsUpper}/;
        }
        $feats .= ' Cf=' . $child->formeme;
        $feats .= ' CfCl=' . $child->formeme .'_'. lemma_or_tag($child);
    }

    # VW format does not allow ":"
    $feats =~ s/:/;/g;
    $en_tlemma =~ s/:/;/g;
    $cs_tlemma =~ s/:/;/g;

    # VW LDF (label-dependent features) format output
    print { $self->_file_handle() } "shared |S $feats\n" if $self->shared_format;
    my ($i);
    foreach my $variant (keys %{$submodel}){
        $i++;
        $variant =~ s/:/;/g;
        my $cost = $variant eq $cs_tlemma ? 0 : 1;
        if ($self->shared_format){
            print { $self->_file_handle() } "$i:$cost |T $en_tlemma^$variant\n";
        } else {
            print { $self->_file_handle() } "$i:$cost |S=$en_tlemma,T=$variant $feats\n";
        }
    }
    print { $self->_file_handle() } "\n";
    return;
}

sub add {
    my ($tnode, $name, $attr) = @_;
    my $value;
    if ($attr eq '_article'){
        $value = first {/^(an?|the)$/} map {lc $_->form} $tnode->get_aux_anodes;
    } elsif ($attr eq '_ne_type'){
        if ( my $n_node = $tnode->get_n_node() ) {
            $value = $n_node->ne_type;
        }
    }
    else {
        $value = $tnode->get_attr($attr);
    }

    return '' if !defined $value;
    $value =~ s/ /&#32;/g;

    # Return the lemma if it is frequent enough. Otherwise return PennTB PoS tag.
    # TODO: use something better than the static dictionary.
    if ($attr eq 't_lemma' && !$static->_submodels->{$value}){
        my $anode = $tnode->get_lex_anode() or return '';
        $value = $anode->tag;
    }

    # Shorten sempos
    $value =~ s/\..+// if $attr eq 'gram/sempos';

    return " $name=$value";
}

# Hack to include coarse-grained PoS tag for Czech lemma.
# $tnode->get_attr('mlayer_pos') is not filled in CzEng
sub lemmapos {
    my ($tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;
    my $anode = $tnode->get_lex_anode or return $lemma;
    my ($pos) = ( $anode->tag =~ /^(.)/ );
    return $lemma if !defined $pos;
    return "$lemma#$pos";
}

# For English
sub lemma {
    my ($tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;
    return $lemma;
}

sub lemma_or_tag {
    my ($tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;

    # Return the lemma if it is frequent enough.
    # TODO: use something better than the static dictionary.
    return $lemma if $static->_submodels->{$lemma};

    # Otherwise, return the PennTB PoS tag
    my $anode = $tnode->get_lex_anode();
    return $anode->tag if $anode;
    return '';
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
