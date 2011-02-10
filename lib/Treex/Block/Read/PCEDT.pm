package Treex::Block::Read::PCEDT;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseReader';
with 'Treex::Core::DocumentReader';

use Treex::PML::Factory;
my $pmldoc_factory = Treex::PML::Factory->new();

my @languages = qw(cs en);

has schema_dir => (
    isa => 'Str',
    is => 'ro',
    documentation => 'directory with pml-schemata for PCEDT data',
    required => 1,
    trigger => sub { my ($self,$dir)=@_; Treex::PML::AddResourcePath($dir); }
);

sub next_document {
    my ($self) = @_;

    my $base_filename = $self->next_filename or return;
    $base_filename =~ s/(en|cs)\.[atp]\.gz//;

    my $document = Treex::Core::Document->new();
    my %pmldoc;

    foreach my $language (@languages) {
	my $filename = "${base_filename}$language.t.gz";
	log_info "Loading $filename";
  	$pmldoc{$language}{t} =  $pmldoc_factory->createDocumentFromFile($filename);
    }

    log_fatal "different number of trees in Czech and English t-files"
	if $pmldoc{en}{t}->trees != $pmldoc{cs}{t}->trees; 


    foreach my $tree_number (0..$pmldoc{en}{t}->trees) {
	foreach my $language (@languages) {

	}
    }


    return $document;
}

1;
