package Treex::Tool::DerivMorpho::Scenario;

use Moose;
use MooseX::SemiAffordanceAccessor;
use Treex::Core::Log;

has from_file => (
    is            => 'ro',
    isa           => 'Str',
    predicate     => '_has_from_file',
    documentation => q(Path to file with scenario),
);
has from_string => (
    is            => 'ro',
    isa           => 'Str',
    predicate     => '_has_from_string',
    documentation => q(String with scenario),
);

has scenario_string => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_scenario_string',
    lazy     => 1,
);

has block_items => (
    is       => 'rw',
    isa      => 'ArrayRef',
    builder  => '_parse_scenario_and_init_blocks',
    init_arg => undef,
    lazy     => 1,
);

sub apply_to_dictionary {
    my ($self, $dictionary) = @_;

    foreach my $block (@{$self->block_items}) {
        log_info "Applying ".ref($block);
        $dictionary = $block->process_dictionary($dictionary);
    }
}

sub _build_scenario_string {
    my $self = shift;

    if ( $self->_has_from_file ) {
        return $self->_load_scenario_file( $self->from_file );
    }

    elsif ( $self->_has_from_string ) {
        return $self->from_string;
    }

    log_fatal("You have to provide from_file or from_string attribute");
}

sub _load_scenario_file {
    my ( $self, $scenario_filename ) = @_;
    log_info "Loading scenario description $scenario_filename";
    my $scenario_string = read_file( $scenario_filename, binmode => ':utf8', err_mode => 'quiet' )
        or log_fatal "Can't open scenario file $scenario_filename";
    return $scenario_string;
}

sub _parse_scenario_and_init_blocks {
    my $self = shift;
    my $scenario_string = $self->scenario_string;

    $scenario_string =~ s/\s+/ /;
    $scenario_string =~ s/^ //;
    $scenario_string =~ s/ $//;

    my @tokens = split / /, $scenario_string;
    my @block_sequence;

    foreach my $token (@tokens) {
        if ( $token !~ /(\S+)=(\S+)/ ) {
            push @block_sequence, { _block_name=> $token };
        }
        else {
            $block_sequence[-1]->{ $1} = $2;
        }
    }

    my @initialized_blocks;
    foreach my $block (@block_sequence) {
        my $module = "Treex::Tool::DerivMorpho::Block::$block->{_block_name}";
        eval "require $module" or log_fatal "Can't load $module: $@\n";
        my $code_to_eval = "push \@initialized_blocks, $module->new(\$block);";
        log_info "Initializing $module";
        eval $code_to_eval or log_fatal "Can't initialize block $module: $@";
    }

    $self->set_block_items(\@initialized_blocks);

}


1;
