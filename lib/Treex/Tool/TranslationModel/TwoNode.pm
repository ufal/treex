package Treex::Tool::TranslationModel::TwoNode;
use Moose;
use Treex::Core::Common;
with 'Treex::Tool::Storage::Storable';

has model => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

my @MASKS = (
    [1,2,3], # L***
    [0,2,3], # *F**
    [2,3],   # LF** 
    [0,3],   # *FL*
    [3],     # LFL*
    [0],     # *FLF
    [],      # LFLF
);
my @STARS = ('*') x 3;

sub translate {
    my ($self, $nL, $nF, $pL, $pF) = @_;
    #my %
}

sub load_hadoop_output{
    my ($self, $file_name) = @_;
    open my $FH, '<:encoding(UTF-8)', $file_name;
    my $last_src = '';
    my $translations;
    
    while(<$FH>){
        chomp;
        my ($prob, $src, $trg, $count) = split /\t/, $_, 4;
        
        if ($src ne $last_src){
            my ($node, $parent) = ($src =~ /^([^ ]+ [^ ]+) ([^ ]+ [^ ]+)$/);
            $translations = [];
            $self->model->{$node}{$parent} = $translations;
            #$self->model->{$src} = $translations;
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