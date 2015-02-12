package Treex::Tool::TranslationModel::Model;

use Moose::Role;

use Treex::Core::Common;

use Storable;
use IO::Zlib;
use PerlIO::gzip;
use File::Slurp;

with 'Treex::Tool::Storage::Storable';

requires '_create_submodel';
requires '_get_transl_variants';
requires 'source';

has '_submodels' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

sub add_submodel {
    my ( $self, $input_label, $submodel ) = @_;
    $self->_submodels->{$input_label} = $submodel;
    return;
}

sub get_submodel {
    my ( $self, $input_label ) = @_;
    return $self->_submodels->{$input_label};
}

sub delete_submodel {
    my ( $self, $input_label ) = @_;
    delete $self->_submodels->{$input_label};
    return;
}

sub get_input_labels {
    my ($self) = @_;
    return (keys %{$self->_submodels});
}

sub get_translations {
    my ($self, $input_label, $features) = @_;

    my $submodel = $self->_submodels->{$input_label}
        or return;
    
    my @variants = $self->_get_transl_variants($submodel, $features);

    # Ordering of keys in a Perl hash is not deterministic.
    # However, we want our experiments deterministic,
    # so we need stable (lexicographic) sorting also for variants with the same prob.
    my @results = sort {$b->{prob} <=> $a->{prob} or $a->{label} cmp $b->{label}} @variants;
    return @results;
}
   
sub predict {
    my ($self, $input_label, $features) = @_;
    my ($first_translation) = $self->get_translations($input_label, $features);
    if (defined $first_translation) {
        return $first_translation->{label};
    }
    else {
        return;
    }
}

############# implementing Treex::Tool::Storage::Storable role #################

around 'load_specified' => sub {
    my ($orig, $self, $filename) = @_;
    my $model;
    log_info "Loading " . $self->source . " translation model from $filename...";
    if ( $filename =~ /\.slurp\./ ) {
        $self->$orig($filename);
    } else {
        open my $fh, "<:gzip", $filename or log_fatal($!);
        $model = Storable::retrieve_fd($fh) or log_fatal($!);
        close($fh);
        $self->thaw($model);
    }
};

around 'save' => sub {
    my ($orig, $self, $filename) = @_;
    log_info "Storing " . $self->source . " translation model into $filename...";
    if ( $filename =~ /\.slurp\./ ) {
        $self->$orig($filename);
    } else {
        my $model = $self->freeze();
        open (my $fh, ">:gzip", $filename) or log_fatal $!;
        Storable::nstore_fd($model, $fh) or log_fatal $!;;
        close($fh);
    }
    return;
};

sub thaw {
    my ($self, $model) = @_;
    foreach my $input_label (keys %$model) {
        my $model_buffer = $model->{$input_label};
        my $submodel = $self->_create_submodel();
        $submodel->thaw($model_buffer);
        $self->add_submodel($input_label, $submodel);
    }
    return;
}

sub freeze {
    my ($self) = @_;
    my $model_hash = {};
    foreach my $input_label ($self->get_input_labels) {
        my $submodel = $self->get_submodel($input_label);
        $model_hash->{$input_label} = $submodel->freeze();
    }
    return $model_hash;
}

1;
