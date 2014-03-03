package Treex::Block::Treelets::TrVW;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use TranslationModel::Static::Model;
use File::Temp qw(tempfile);

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

has static_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0.5,
    documentation => 'Weight of the Static model (NB: the model will be loaded even if the weight is zero).'
);

has normalize => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'should the probs sum up to 1?'
);

has vw_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'vw173182.model', # press conference -> tiskové konference 0.0968  4.5083
    #default => 'vw154579.model',  # press conference -> konference tisku   0.0912  4.3835
);


my $static;
my $vw_model_path;
my ($F, $R, $Fname, $Rname);

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
    $vw_model_path = Treex::Core::Resource::require_file_from_share($self->model_dir . '/' . $self->vw_model);
    return;
}

sub process_document {
    my ($self, $doc) = @_;
    
    # print feature vectors into a file
    # $Fname = 'features.dat'; open $F, '>:utf8', $Fname;
    ($F, $Fname) = tempfile('VWfeatsXXXXXX', TMPDIR => 1); # For debugging TMPDIR => 0 will use the current directory
    binmode( $F, ":utf8" );
    
    foreach my $bundle ($doc->get_bundles()){
        my @zones = $self->get_selected_zones($bundle->get_all_zones());
        foreach my $zone (@zones){
           foreach my $tnode ($zone->get_ttree()->get_descendants()) {
               $self->print_tnode($tnode);
           }
        }
    }
    close $F;
      
    # run VW prediction
    ($R, $Rname) = tempfile('VWrawXXXXXX', TMPDIR => 1);
    close $R;
    system "vw -i $vw_model_path --quiet -d $Fname -r $Rname";
    
    # Fill the predictions into the Treex doc
    open $R, '<:utf8', $Rname;
    foreach my $bundle ($doc->get_bundles()){
        my @zones = $self->get_selected_zones($bundle->get_all_zones());
        foreach my $zone (@zones){
           foreach my $tnode ($zone->get_ttree()->get_descendants()) {
               $self->fill_tnode($tnode);
           }
        }
    }
    close $R;

    # Clean up the temporary files
    unlink $Fname, $Rname;
    return 1;
}

sub fill_tnode {
    my ( $self, $cs_tnode ) = @_;
    
    # Skip nodes that were already translated by rules
    #return if $cs_tnode->t_lemma_origin ne 'clone'; TODO: vratit zpet
    my $en_tnode = $cs_tnode->src_tnode;
    return if !$en_tnode;
    
    #return if $en_tnode->functor =~ /CONJ|DISJ|ADVS|APPS/;
    my $en_tlemma = lemma($en_tnode);    
    return if $en_tlemma !~ /\p{IsL}/;
    
    # Skip instances where the English lemma is not listed in the Static model.
    my $submodel = $static->_submodels->{$en_tlemma};
    return if !$submodel;
    
    my @translations;
    my $sum = 0;
    while (<$R>){
        chomp;
        last if $_ eq '';
        #log_warn "Strange VW -r output: $_" if !/^\d+:(-?[\d.]+) ([^ ]+)$/
        my ($score, $variant) = (/^\d+:([-e\d.]+) ([^ ]+)$/) or log_fatal "Strange VW -r output: $_";
        #csoaa predicts the loss, so instead of -$score, we need +$score
        $score = 1.0 / (1.0 + exp($score));
        # interpolate with static
        $score += $self->static_weight * $submodel->{$variant};
        $score /= (1 + $self->static_weight);
        $sum += $score;
        push @translations, [$score, $variant];
    }
    log_fatal "No VW translations for $en_tlemma in $Rname trained from $Fname" if !@translations;
    $sum = 1 if !$self->normalize;
    
    
    # Sort: the highest prob first. We need deterministic runs and therefore stable sorting for equally probable translations.
    @translations = sort {($b->[0] <=> $a->[0]) || ($a->[1] cmp $b->[1])} @translations;

    if ( $translations[0][1] =~ /(.+)#(.)/ ) {
        $cs_tnode->set_t_lemma($1);
        $cs_tnode->set_attr( 'mlayer_pos', $2 );
    } else {
        log_fatal "Unexpected form of label: " . $translations[0][1];
    }
    $cs_tnode->set_attr('t_lemma_origin', ( @translations == 1 ? 'dict-only' : 'dict-first' ) . "|VW");
    $cs_tnode->set_attr(
                'translation_model/t_lemma_variants',
                [   map {
                        $_->[1] =~ /(.+)#(.)/ or log_fatal "Unexpected form of label: $_->[1]";
                        {   't_lemma' => $1,
                            'pos'     => $2,
                            'origin'  => 'VW',
                            'logprob' => prob2binlog( $_->[0]/$sum ),
                            #'feat_weights' => $_->{feat_weights},
                            # 'backward_logprob' => _logprob( $_->{en_given_cs}, ),
                        }
                        } @translations
                ]
            );
    
    return;
}

sub print_tnode {
    my ( $self, $cs_tnode ) = @_;
    
    # Skip nodes that were already translated by rules
    #return if $cs_tnode->t_lemma_origin ne 'clone'; TODO: vratit zpet
    my $en_tnode = $cs_tnode->src_tnode;
    return if !$en_tnode;
    
    #return if $en_tnode->functor =~ /CONJ|DISJ|ADVS|APPS/;
    my $en_tlemma = lemma($en_tnode);    
    return if $en_tlemma !~ /\p{IsL}/;
    
    # Skip instances where the English lemma is not listed in the Static model.
    my $submodel = $static->_submodels->{$en_tlemma};
    return if !$submodel;

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

    # VW LDF (label-dependent features) format output
    print {$F} "shared |S $feats\n" if $self->shared_format;
    my ($i);
    foreach my $variant (keys %{$submodel}){
        $i++;
        $variant =~ s/:/;/g;
        if ($self->shared_format){
            print {$F} "$i $variant|T $en_tlemma^$variant\n";
        } else {
            print {$F} "$i $variant|S=$en_tlemma,T=$variant $feats\n";
        }
    }
    print { $F } "\n";
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

my $LOG2 = log 2;
sub prob2binlog {
    my $prob = shift;
    if ($prob > 1 or $prob <= 0) {
        log_fatal "probability value $prob is not within the required interval";
      }
    return log($prob) / $LOG2;
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
