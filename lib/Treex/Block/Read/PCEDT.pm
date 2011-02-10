package Treex::Block::Read::PCEDT;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseReader';
with 'Treex::Core::DocumentReader';

use Treex::PML::Factory;
my $pmldoc_factory = Treex::PML::Factory->new();

my @languages = qw(cs en);
my @layers = qw(a t p);


# temporary hack, because p-files have a wrong reference to their schema
Treex::PML::AddResourcePath("/net/os/h/zabokrtsky/tectomt/devel/pml_schemas/");

has schema_dir => (
    isa => 'Str',
    is => 'ro',
    documentation => 'directory with pml-schemata for PCEDT data',
    required => 1,
    trigger => sub { my ($self,$dir)=@_; Treex::PML::AddResourcePath($dir); }
);


sub _copy_attr {
    my ($pml_node, $treex_node, $old_attr_name, $new_attr_name) = @_;
    $treex_node->set_attr($new_attr_name,$pml_node->attr($old_attr_name));

}


sub _convert_ttree {
    my ( $pml_node, $treex_node ) = @_;

    if ($treex_node->is_root) {
        foreach my $attr_name ('id','atree.rf') {
            _copy_attr($pml_node, $treex_node, $attr_name, $attr_name);
        }
    }

    else {
        _copy_attr($pml_node, $treex_node, 'deepord', 'ord');
        foreach my $attr_name ('t_lemma','functor','id') {
            _copy_attr($pml_node, $treex_node, $attr_name, $attr_name);
        }
    }

    foreach my $pml_child ( $pml_node->children) {
        my $treex_child = $treex_node->create_child;
        _convert_ttree($pml_child, $treex_child);
    }
}

sub _convert_atree {
    my ( $pml_node, $treex_node ) = @_;

    foreach my $attr_name ('id','ord') {
        _copy_attr($pml_node, $treex_node, $attr_name, $attr_name);
    }

    if (not $treex_node->is_root) {
        _copy_attr($pml_node, $treex_node, 'm/w/no_space_after', 'no_space_after');
        foreach my $attr_name ('form','lemma','tag','afun') {
            _copy_attr($pml_node, $treex_node, "m/$attr_name", $attr_name);
        }
    }

    foreach my $pml_child ( $pml_node->children) {
        my $treex_child = $treex_node->create_child;
        _convert_atree($pml_child, $treex_child);
    }
}



sub next_document {
    my ($self) = @_;

    my $base_filename = $self->next_filename or return;
    $base_filename =~ s/(en|cs)\.[atp]\.gz//;

    my %pmldoc;

    foreach my $language (@languages) {
        foreach my $layer (@layers) {
            next if $layer eq "p" and $language eq "cs";
            my $filename = "${base_filename}$language.${layer}.gz";
            log_info "Loading $filename";
            $pmldoc{$language}{$layer} =  $pmldoc_factory->createDocumentFromFile($filename);
        }
    }

    log_fatal "different number of trees in Czech and English t-files"
	if $pmldoc{en}{t}->trees != $pmldoc{cs}{t}->trees;

    my $document = Treex::Core::Document->new();

    foreach my $tree_number (0 .. ($pmldoc{en}{t}->trees - 1) ) {

        my $bundle = $document->create_bundle;
	foreach my $language (@languages) {
            my $zone = $bundle->create_zone($language);

            my $troot = $zone->create_ttree;
            _convert_ttree($pmldoc{$language}{t}->tree($tree_number), $troot);

            my $aroot = $zone->create_atree;
            _convert_atree($pmldoc{$language}{a}->tree($tree_number), $aroot);

            $zone->set_sentence($aroot->get_sentence_string);

#            if ($language eq 'en') {
#                my $proot = $zone->create_ptree;
#            }
	}
    }


    return $document;
}

1;
