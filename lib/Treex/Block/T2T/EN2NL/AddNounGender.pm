package Treex::Block::T2T::EN2NL::AddNounGender;

use Moose;
use Treex::Core::Common;
use Storable qw(retrieve);

extends 'Treex::Core::Block';

has '_genders' => ( is => 'ro', isa => 'HashRef', builder => '_build_genders', lazy_build => 1 );

has 'gender_file' => ( is => 'ro', isa => 'Str', default => 'data/models/lexicon/nl/genders.pls' );

sub _build_genders {
    my ($self)        = @_;
    my ($gender_file) = $self->require_files_from_share( $self->gender_file );
    return retrieve($gender_file);
}

my %GENDER_MAPPING = (
    'com'  => 'inan',    # hack: using Czech grammateme 'inan' for common gender
    'neut' => 'neut',
    'both' => 'inan',    # map both genders to de-words
);

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # do not set gender in non-nouns, do not override pronoun gender
    return if ( !$tnode->gram_sempos =~ /^n/ or $tnode->gram_gender or !$tnode->t_lemma );

    my $gender = $self->_genders->{ $tnode->t_lemma };
    if ($gender) {
        $gender = $GENDER_MAPPING{$gender} or return;
        $tnode->set_gram_gender($gender);
    }
    return;
}

1;
