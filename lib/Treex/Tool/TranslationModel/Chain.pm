package Treex::Tool::TranslationModel::Chain;
use Moose;
use Treex::Core::Common;
with 'Treex::Tool::Storage::Storable';

has model => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

sub load_hadoop_output{
    my ($self, $file_name) = @_;
    open my $FH, '<:encoding(UTF-8)', $file_name;
    my $last_src = '';
    my $translations;
    
    while(<$FH>){
        chomp;
        my ($prob, $src, $trg, $count) = map {remove_stars($_)} split /\t/, $_, 4;
        if ($src ne $last_src){
            $translations = [];
            $self->model->{$src} = $translations;
            $last_src = $src;
        }
        push @$translations, $trg => $prob;
    }
    close $FH;
    return;
}

sub load_hadoop_dir{
    my ($self, $dir_name) = @_;
    foreach my $file_name (glob "$dir_name/part*"){
        $self->load_hadoop_output($file_name);
    }
    return;
}

sub remove_stars {
    return join ' ', grep {$_ ne '*'} split / /, shift;
}

sub freeze {
    my ($self) = @_;
    return $self->model;
}

sub thaw {
    my ($self, $buffer) = @_;
    $self->set_model($buffer);
    return;
}

before save => sub {
    my ($self, $filename) = @_;
    log_info "Storing Chain model into $filename...";
};

before load => sub {
    my ($self, $filename) = @_;
    log_info "Loading Chain model from $filename...";
};
1;