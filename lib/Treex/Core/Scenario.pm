package Treex::Core::Scenario;
use Moose;
use Treex::Core::Common;
use File::Basename;
use File::Slurp;
use File::chdir;
use Parse::RecDescent 1.967003;

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
    lazy    => 1,
);

has block_items => (
    is       => 'ro',
    isa      => 'ArrayRef[HashRef]',
    builder  => 'parse_scenario_string',
    init_arg => undef,
    lazy     => 1,
);

has loaded_blocks => (
    is        => 'ro',
    isa       => 'ArrayRef[Treex::Core::Block]',
    builder   => '_build_loaded_blocks',
    predicate => 'is_initialized',
    lazy      => 1,
    init_arg  => undef,
);

has document_reader => (
    is            => 'ro',
    does          => 'Treex::Core::DocumentReader',
    predicate     => '_has_document_reader',
    writer        => '_set_document_reader',
    init_arg      => undef,
    documentation => 'DocumentReader starts every scenario and reads a stream of documents.'
);

has _global_params => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        get_global_param => 'get',
        set_global_param => 'set',

        #get_global_param_names => 'keys',
        #set_verbose       => [ set => 'verbose' ],
        #get_verbose       => [ get => 'verbose' ],
        #set_language      => [ set => 'language' ],
        #get_language      => [ get => 'language' ],
        #... ?
    },
);

has parser => (
    is            => 'ro',
    isa           => 'Parse::RecDescent',
    init_arg      => undef,
    builder       => '_build_parser',
    documentation => q{Parses treex scenarios}
);

has runner => (
    is            => 'ro',
    isa           => 'Treex::Core::Run',
    writer        => '_set_runner',
    weak_ref      => 1,
    documentation => 'Treex::Core::Run instance in which the scenario is running',
);

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

sub _build_loaded_blocks {
    my $self        = shift;
    my @block_items = @{ $self->block_items };
    my $block_count = scalar @block_items;
    my $i           = 0;
    my @loaded_blocks;
    foreach my $block_item (@block_items) {
        $i++;
        my $params = '';
        if ( $block_item->{block_parameters} ) {
            $params = join ' ', @{ $block_item->{block_parameters} };
        }
        log_info("Loading block $block_item->{block_name} $params ($i/$block_count)");
        my $new_block = $self->_load_block($block_item);

        log_debug( $block_item->{block_name} );
        if ( $new_block->does('Treex::Core::DocumentReader') ) {
            log_fatal("Only one DocumentReader per scenario is permitted ($block_item->{block_name})")
                if $self->_has_document_reader;
            $self->_set_document_reader($new_block);
        }
        else {
            push @loaded_blocks, $new_block;
        }
    }
    log_info('');
    log_info('   ALL BLOCKS SUCCESSFULLY LOADED.');
    log_info('');
    return \@loaded_blocks;
}

sub _load_parser {
    my $self = shift;
    require Treex::Core::ScenarioParser;
    return Treex::Core::ScenarioParser->new();
}

sub _my_dir {
    return dirname( (caller)[1] );
}

sub _build_parser {
    my $self = shift;
    my $parser;
    eval {
        $parser = $self->_load_parser();
        1;
    } and return $parser;
    log_info("Cannot find precompiled scenario parser, trying to build it from grammar");
    my $dir  = $self->_my_dir();             #get module's directory
    my $file = "$dir/ScenarioParser.rdg";    #find grammar file
    log_fatal("Cannot find grammar file") if !-e $file;
    my $grammar = read_file($file);          #load it
    eval {
        log_info("Trying to precompile it for you");
        local $CWD = $dir;
        Parse::RecDescent->Precompile( $grammar, 'Treex::Core::ScenarioParser' );
        $parser = $self->_load_parser();
        1;
    } or eval {
        log_info("Cannot precompile, loading directly from grammar. Consider precompiling it manually");
        $parser = Parse::RecDescent->new($grammar);    #create parser
        1;
    } or log_fatal("Cannot create Scenario parser");
    return $parser;
}

sub _load_scenario_file {
    my ( $self, $scenario_filename ) = @_;
    log_info "Loading scenario description $scenario_filename";
    my $scenario_string = read_file( $scenario_filename, binmode => ':utf8', err_mode => 'quiet' )
        or log_fatal "Can't open scenario file $scenario_filename";
    return $scenario_string;
}

sub parse_scenario_string {
    my $self            = shift;
    my $scenario_string = $self->scenario_string;
    my $from_file       = $self->from_file;

    my $parsed = $self->parser->startrule( $scenario_string, 1, $from_file );
    log_fatal("Cannot parse the scenario: $scenario_string") if !defined $parsed;
    return $parsed;
}

# reverse of parse_scenario_string, used in Treex::Core::Run for treex --dump
sub construct_scenario_string {
    my $self        = shift;
    my %args        = @_;
    my $multiline   = $args{multiline};
    my @block_items = @{ $self->block_items };
    my $delim       = $multiline ? qq{\n} : q{ };
    my @block_strings;
    foreach my $block_item (@block_items) {
        my $name = $block_item->{block_name};
        my @parameters = map { _add_quotes($_) } @{ $block_item->{block_parameters} };
        $name =~ s{^Treex::Block::}{} or $name = "::$name";    #strip leading Treex::Block:: or add leading ::
        my $params;
        if ( scalar @parameters ) {
            $params = q{ } . join q{ }, @parameters;
        }
        else {
            $params = q{};
        }
        push @block_strings, $name . $params;
    }
    return join $delim, @block_strings;
}


# reverse of parse_scenario_string, used in Treex::Core::Run for treex --dump
sub get_required_files {
    my $self        = shift;
    my @block_items = @{ $self->block_items };
    my @required_files;
    foreach my $block_item (@block_items) {
        my $block = $self->_load_block($block_item);
        push @required_files,
            map {
                $block_item->{block_name} . "\t" . $_;
            } $block->get_required_share_files();
    }
    return @required_files;
}

sub _add_quotes {    # adding quotes only if param. value contains a space
    my ($block_parameter) = @_;
    my ( $name, $value ) = split /=/, $block_parameter, 2;
    if ( $value =~ /\s/ ) {
        return "$name=\"$value\"";
    }
    return $block_parameter;
}

sub load_blocks {
    my $self = shift;
    $self->loaded_blocks;    #just access lazy attribute
    return;
}

sub init {
    my $self = shift;
    $self->load_blocks();
    return;
}

sub _load_block {
    my ( $self, $block_item ) = @_;
    my $block_name = $block_item->{block_name};
    my $new_block;

    # Initialize with global (scenario) parameters
    my %params = ( %{ $self->_global_params }, scenario => $self );

    # which can be overriden by (local) block parameters.
    foreach my $param ( @{ $block_item->{block_parameters} } ) {
        my ( $name, $value ) = split /=/, $param, 2;
        $params{$name} = $value;
    }

    eval "use $block_name; 1;" or log_fatal "Can't use block $block_name !\n$@\n";
    eval {
        $new_block = $block_name->new( \%params );
        1;
    } or log_fatal "Treex::Core::Scenario->new: error when initializing block $block_name\n\nEVAL ERROR:\t$@";

    return $new_block;
}

sub run {
    my ($self) = @_;
    my $number_of_blocks = @{ $self->loaded_blocks };
    log_fatal('No DocumentReader supplied') if !$self->_has_document_reader;
    my $reader              = $self->document_reader;
    my $number_of_documents = $reader->number_of_documents_per_this_job() || '?';
    my $document_number     = 0;

    log_info "Applying process_start";
    foreach my $block ( @{ $self->loaded_blocks } ) {
        $block->process_start();
    }

    while ( my $document = $reader->next_document_for_this_job() ) {
        $document_number++;
        my $doc_name = $document->full_filename;
        my $doc_from = $document->loaded_from;
        log_info "Document $document_number/$number_of_documents $doc_name loaded from $doc_from";
        my $block_number = 0;
        foreach my $block ( @{ $self->loaded_blocks } ) {
            $block_number++;
            log_info "Applying block $block_number/$number_of_blocks " . ref($block);
            $block->process_document($document);
        }

        # this actually marks the document as successfully done in parallel processing (if this line
        # does not appear in the output, the parallel process will fail -- it must appear at any errorlevel,
        # therefore not using log_info or similiar)
        if ( $self->document_reader->jobindex ) {
            print STDERR "Document $document_number/$number_of_documents $doc_name: [success].\n";
        }
    }

    log_info "Applying process_end";
    foreach my $block ( @{ $self->loaded_blocks } ) {
        $block->process_end();
    }

    log_info "Processed $document_number document"
        . ( $document_number == 1 ? '' : 's' );
    return 1;
}

use Module::Reload;

sub restart {
    my ($self) = @_;
    my $changed_modules = Module::Reload->check;
    log_info "Number of reloaded modules = $changed_modules";
    log_info "reseting the document reader\n";
    $self->document_reader->restart();

    # TODO rebuild the reloaded blocks
    return;
}

1;

__END__


=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Scenario - a larger Treex processing unit, composed of blocks

=head1 SYNOPSIS

 use Treex::Core;
 
 my $scenario = Treex::Core::Scenario->new(from_file => 'myscenario.scen' );
 
 $scenario->run;


=head1 DESCRIPTION


A Treex scenario consists of a sequence of (possibly parametrized) Treex blocks.

Scenarios can be described by a simple textual format, which is either passed
directly to the scenario construction, or is contained in a text file whose
name is passed.

The string description of scenarios looks as follows.

1) It contains a list of block names from which their 'C<Treex::Block::>'
prefixes were removed.

2) The block names are separated by one or more white spaces.

3) The block names are listed in the same order in which they should be
applied on data.

4) For each block, there can be one or more parameters specified, using the
C<attribute=value> form.

5) Comments start with 'C<#>' and end with the nearest newline character.


Scenario example:

 # morphological analysis of an English text
 Util::SetGlobal language=en selector=src
 Read::Text
 W2A::ResegmentSentences
 W2A::EN::Tokenize
 W2A::EN::NormalizeForms
 W2A::EN::FixTokenization
 W2A::EN::TagMorce


=head1 METHODS

=head2 Constructor

=over 4

=item my $scenario = Treex::Core::Scenario->new(from_string => 'W2A::Tokenize language=en  W2A::Lemmatize' );

Constructor parameter C<from_string> specifies the names of blocks which are 
to be executed (in the specified order) when the scenario is applied on a 
L<Treex::Core::Document> object.

=item my $scenario = Treex::Core::Scenario->new(from_file => 'myscenario.scen' );

The scenario description is loaded from the file.

=back


=head2 Running the scenario

=over 4

=item $scenario->run();

Run the scenario.
One of the blocks (usually the first one) must be the document reader (see
L<Treex::Core::DocumentReader>) that produces the
documents on which this scenario is applied.

=back

=head2 Internal methods for loading scenarios

=over 4

=item _load_scenario_file($filename)

loads a scenario description from a file

=item parse_scenario_string

parses a textual description of a scenario

=item construct_scenario_string

constructs a scenario textual description from an existing scenario instance
accepts named parameter multiline - when set, blocks are separated by newline instead of space

=item load_blocks

use blocks and call their constructors
can be used for preloading blocks for e.g. server applications
when running scenario blocks are loaded automatically

=item init

do all initialization so after this method scenario is ready to run
currently just load blocks

=item restart

resets the document reader, in future it will rebuild reloaded blocks

=back


=head1 SEE ALSO

L<Treex::Core::Block>
L<Treex::Core>

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
