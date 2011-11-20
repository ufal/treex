package Treex::Tool::Coreference::SynonTranslDictModel;
use Moose;
use Treex::Core::Common;


has 'model_path' => (
    is => 'ro', isa => 'Str', required => 1,
    default => 'data/models/coreference/CS/features/synonyms_from_transl_dict',
);
has '_pair_f' => (
    is => 'ro', isa => 'HashRef[HashRef[Int]]',
    lazy    => 1,
    builder => '_build__pair_f',
);

sub BUILD {
    my ($self) = @_;
    $self->_pair_f;
}

sub _build__pair_f {
    my ($self) = @_;

    my $pair_f = $self->_load_model();
    return $pair_f;
}

sub _load_model {
    my ($self) = @_;

    my $model_file = require_file_from_share($self->model_path, ref($self));
    log_fatal 'File ' . $model_file . 
        ' with a model for coreference segmentation does not exist.' 
        if !-f $model_file;
    open I, "<:utf8", $model_file or die $!;
    
    my %pair_f;
    while (my $pair = <I>) {
        chomp $pair;
        my ($lemma1, $lemma2, $f) = split /\t/, $pair;
        $lemma1 =~ s/#N//;
        $lemma2 =~ s/#N//;

        $pair_f{$lemma1}{$lemma2} += $f;
        $pair_f{$lemma2}{$lemma1} += $f;
    }
    close I;
    return (\%pair_f);
}

sub are_synonymous {
    my ($self, $lemma1, $lemma2) = @_;

    my $score = $self->_pair_f->{$lemma1}{$lemma2};
    if (defined $score && ($score != 0)) {
        return 1;
    }
    else {
        return 0;
    }
}

1;
