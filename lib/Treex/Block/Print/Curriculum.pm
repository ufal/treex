package Treex::Block::Print::Curriculum;

use Moose;
use Treex::Core::Common;
use Lingua::Interset 2.050;
use Lingua::Interset::FeatureStructure;
use utf8;

extends 'Treex::Core::Block';

#use SentInfoGetter;

has 'src_language' => (
    is => 'rw',
    isa => 'Str',    
    required => 1
);
has 'src_selector' => (
    is => 'rw',
    isa => 'Str',
    default => ""
);
has 'tgt_language' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);
has 'tgt_selector' => (
    is => 'rw',
    isa => 'Str',
    default => ""
);


#has '+extension' => ( default => '.tsv' );
#has '+stem_suffix' => ( default => '_curriculum' );
#has '+compress' => ( default => '1' );

sub process_zone {
    my ( $self, $zone ) = @_;
    my $info = {};

    my $src_zone =
        $zone->get_bundle()
        ->get_zone( $self->src_language, $self->src_selector );
    my $tgt_zone =
        $zone->get_bundle()
        ->get_zone( $self->tgt_language, $self->tgt_selector );

    $self->process_atree_recursively($src_zone->get_tree("a"), $info, $self->src_language);
    $self->process_ttree_recursively($src_zone->get_tree("t"), $info, $self->src_language);
    $self->process_atree_recursively($src_zone->get_tree("a"), $info, $self->tgt_language);
    $self->process_ttree_recursively($src_zone->get_tree("t"), $info, $self->tgt_language);

    $self->print_info($info);
}

sub process_atree_recursively {
    my ($self, $anode, $info, $lang) = @_;
       
 
    if (!$anode->is_root()) {
        # Update Nodecount info
        $info->{$lang ."_anodes"}++;
        # Update Interset info
        my $value;
        foreach my $feature (Lingua::Interset::FeatureStructure->known_features()) {
            $value = $anode->get_iset($feature);
            $info->{$lang ."_". $feature ."_". $value}++;
        }
        # Update Tag info
        $value = $anode->tag;
        $info->{$lang ."_tag_". $value}++;
        # Update Afun info
        $value = $anode->afun;
        $info->{$lang ."_afun_". $value}++;
        # Update NonProjectivity info
        $info->{$lang ."_a-nonproj"}++ if $anode->is_nonprojective();
        
    }
    foreach my $child ($anode->get_children( { ordered => 1 } )) {
        $self->process_atree_recursively($child, $info, $lang);
    }
}

sub process_ttree_recursively {
    my ($self, $tnode, $info, $lang) = @_;

    if(!$tnode->is_root()) {
        # Update Nodecount info
        $info->{$lang ."_tnodes"}++;
        # Update Formeme info
        my $value = $tnode->formeme;
        $info->{$lang ."_formeme_". $value}++;
        # Update Functor info
        $value = $tnode->functor;
        $info->{$lang ."_functor_". $value}++;
        # Update Grammatemes info
        my $gram = $tnode->get_attr('gram');
        foreach my $g (keys %$gram) {
            $value = $gram->{$g};
            $info->{$lang ."_gram/". $g ."_". $value}++;
        }
        # Update NonProjectivity info
        $info->{$lang ."_t-nonproj"}++ if $tnode->is_nonprojective();
    }
    foreach my $child ($tnode->get_children( { ordered => 1 } )) {
        $self->process_ttree_recursively($child, $info, $lang);
    }
}

sub print_info {
    my ($self, $info) = @_;
    my $string = join("\t", map { $_ ."=". $info->{$_} } keys %$info);
    print $string . "\n";
}

1;
