package Treex::Block::Treelets::TrVW;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::TranslationModel::Static::Model;
use Treex::Block::Treelets::SrcFeatures;
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

has VWstatic_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0.45,
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
    default => 'vwN273663.model'
    # vwN272544      0.1248 5.0956
    # vwN273663      0.1249 5.0945
    # vwN283830 BLEU=0.1225
    # vwN285184 BLEU=0.1226
    # vwN291256 BLEU=0.1219
    #default => 'vw173182.model', # press conference -> tiskové konference 0.0968  4.5083
    #default => 'vw154579.model', # press conference -> konference tisku   0.0912  4.3835
);

my $static;
my $src_feature_extractor;
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
    $static = $self->load_model( Treex::Tool::TranslationModel::Static::Model->new(), $self->static_model );
    $src_feature_extractor = Treex::Block::Treelets::SrcFeatures->new();
    $src_feature_extractor->_set_static($static);
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
    return if $cs_tnode->t_lemma_origin ne 'clone';
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
        my ($score, $variant) = (/^\d+:([-e\d.]+) _([^ ]+)$/) or log_fatal "Strange VW -r output: $_";
        #csoaa predicts the loss, so instead of -$score, we need +$score
        $score = 1.0 / (1.0 + exp($score));
        # interpolate with static
        $score += $self->VWstatic_weight * $submodel->{$variant};
        $score /= (1 + $self->VWstatic_weight);
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
    return if $cs_tnode->t_lemma_origin ne 'clone';
    my $en_tnode = $cs_tnode->src_tnode;
    return if !$en_tnode;
    
    #return if $en_tnode->functor =~ /CONJ|DISJ|ADVS|APPS/;
    my $en_tlemma = lemma($en_tnode);    
    return if $en_tlemma !~ /\p{IsL}/;
    
    # Skip instances where the English lemma is not listed in the Static model.
    my $submodel = $static->_submodels->{$en_tlemma};
    return if !$submodel;

    # Features from the local tree (and word-order) context this node
    my $src_context_feats = $src_feature_extractor->features_of_tnode($en_tnode);

    # VW format does not allow ":"
    $en_tlemma =~ s/:/;/g;

    my ($best_static_score) = sort {$b <=> $a} (values %{$submodel});

    # VW LDF (label-dependent features) format output
    print {$F} "shared |S $src_context_feats\n" if $self->shared_format;
    my ($i);
    while ( my ($variant, $variant_static_score) = each %{$submodel}){
        $i++;
        $variant =~ s/:/;/g;

        # Target-partial features
        # Default for t_lemma="#PersPron" (dropped)
        my $variant_pos = ($variant =~ /#(.)$/) ? $1 : 'X';
        
        my $static_rank = int log(5*$best_static_score / $variant_static_score);

        if ($self->shared_format){
            print {$F} "$i _$variant|T $en_tlemma^$variant $en_tlemma^$variant_pos |R r$static_rank\n";
        } else {
            print {$F} "$i _$variant|S=$en_tlemma,T=$variant $src_context_feats\n";
        }
    }
    print { $F } "\n";
    return;
}

sub lemma {
    my ($tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;
    return $lemma;
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

Treex::Block::Treelets::TrVW - translate lemmas using VW

=head1 DESCRIPTION

Vowbal Wabbit in the csoaa_ldf=mc format

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
