package Treex::Block::W2A::ConvertTags;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'ta::tamiltb',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
	my $root = $zone->get_atree();
	$self->convert_tags($root); 
}

1;
