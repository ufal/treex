package Treex::Tool::TranslationModel::TwoNode;
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
        my ($count, $src, $trg) = split /\t/, $_, 3;
        #say "ncount=$count\tsrc=$src\ttrg=$trg";
        
        if ($src ne $last_src){
            my ($node, $child) = split / /, $src;
            $child ||= '_NO';
            $translations = [];
            $self->model->{$node}{$child} = $translations;
            $last_src = $src;
        }

        push @$translations, $trg => $count;
        
    }
    close $FH;
    
    #print Dumper $self->model->{'value|*'};
    return;
}

sub load_hadoop_dir{
    my ($self, $dir_name) = @_;
    foreach my $file_name (glob "$dir_name/part*"){
        $self->load_hadoop_output($file_name);
    }
    return;
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
    log_info "Storing TwoNode model into $filename...";
};

before load => sub {
    my ($self, $filename) = @_;
    log_info "Loading TwoNode model from $filename...";
};
1;