package Treex::Core::Scenario;

use Moose;
use Treex::Core::Common;
use File::Basename;
use File::Slurp;
use File::chdir;
use Digest::MD5 qw(md5_hex);

#use Parse::RecDescent 1.967003; now using standalone version

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
    is            => 'rw',
    does          => 'Treex::Core::DocumentReader',
    predicate     => '_has_document_reader',
    writer        => '_set_document_reader',
    init_arg      => undef,
    documentation => 'DocumentReader starts every scenario and reads a stream of documents.'
);

has writers => (
    is      => 'rw',
    does    => 'ArrayRef[Treex::Block::Write::BaseWriter]',
    default => sub { [] }
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
    isa           => 'Parse::RecDescent::_Runtime',
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

has cache => (
    is      => 'rw',
    isa     => 'Maybe[Cache::Memcached]',
    builder => '_build_cache',
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

my %sequence = ();

sub _build_loaded_blocks {
    my $self        = shift;
    my @block_items = @{ $self->block_items };
    my $block_count = scalar @block_items;
    my $i           = 0;
    my @loaded_blocks;

    my $sequence_from = 0;
    my $sequence_hash = "";
    foreach my $block_item (@block_items) {
        $i++;
        my $params = '';
        if ( $block_item->{block_parameters} ) {
            $params = join ' ', @{ $block_item->{block_parameters} };
        }
        log_info("Loading block $block_item->{block_name} $params ($i/$block_count)");
        my $new_block = $self->_load_block($block_item);

        if ( $new_block->does('Treex::Core::DocumentReader') ) {
            log_fatal("Only one DocumentReader per scenario is permitted ($block_item->{block_name})")
                if $self->_has_document_reader;
            $self->_set_document_reader($new_block);
        }
        elsif ( $new_block->isa('Treex::Block::Write::BaseWriter') ) {
            push( @{ $self->writers }, $new_block );
            push @loaded_blocks, $new_block;    # duplicity
        }
        else {
            if ( ref($new_block) eq "Treex::Core::CacheBlock" ) {
                $sequence{$sequence_from}{from} = $sequence_from;
                $sequence{$sequence_from}{to}   = $i;
                $sequence{$sequence_from}{hash} = $sequence_hash;

                $sequence{$i}{_from} = $sequence_from;
                $sequence_from = $i;
                push( @{ $sequence{$sequence_from}{block} }, $new_block->get_hash() );
                $sequence_hash = $new_block->get_hash();
            }
            elsif ($self->cache) {
                $sequence_hash = md5_hex( $sequence_hash . $new_block->get_hash() );
                if ( defined( $sequence{$sequence_from} ) ) {
                    push( @{ $sequence{$sequence_from}{block} }, $new_block->get_hash() );
                }
            }

            push @loaded_blocks, $new_block;
        }
    }

    log_info('ALL BLOCKS SUCCESSFULLY LOADED.');
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

    #in fact we should never reach this
    log_warn('We should NOT reach this place. Treex distribution may be corrupted.');

    my $grammar = read_file($file);          #load it
    eval {
        log_info("Trying to precompile it for you");
        require Parse::RecDescent;
        local $CWD = $dir;
        Parse::RecDescent->Precompile( { -standalone => 1 }, $grammar, 'Treex::Core::ScenarioParser' );
        $parser = $self->_load_parser();
        1;
    } or eval {
        log_info("Cannot precompile, loading directly from grammar. Consider precompiling it manually");
        require Parse::RecDescent;
        $parser = Parse::RecDescent->new($grammar);    #create parser
        1;
    } or log_fatal("Cannot create Scenario parser");
    return $parser;
}

sub _build_cache {
    my $self = shift;
    
    if ( $self->runner && $self->runner->cache ) {
        
        require Treex::Core::CacheBlock;
        require Treex::Tool::Memcached::Memcached;
        
        return Treex::Tool::Memcached::Memcached::get_connection(
            "documents-cache"
        );
    }

    return;
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
        my $res_string = "$name=";

        if ( $value =~ /'/ && $value !~ /"/ ) {
            $res_string .= '"' . $value . '"';
        } else {
            $value =~ s/'/\\'/g;
            $res_string .= "'" . $value . "'";
        }
        return $res_string;
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

    if ( $self->cache && $params{'use_cache'} ) {
        $new_block = Treex::Core::CacheBlock->new( { block => $new_block, cache => $self->cache } );
    }

    return $new_block;
}

sub run {
    my ($self) = @_;
    my $number_of_blocks = @{ $self->loaded_blocks };
    log_fatal('No DocumentReader supplied') if !$self->_has_document_reader;
    my $reader              = $self->document_reader;
    my $number_of_documents = $reader->number_of_documents_per_this_job() || '?';
    my $document_number     = 0;

    #if ( $self->cache ) {
    #    $document_number = $self->_run_with_cache( $reader, $number_of_blocks, $number_of_documents );
    #}
    #else {
        $document_number = $self->_run_without_cache( $reader, $number_of_blocks, $number_of_documents );
    #}

    log_info "Processed $document_number document"
        . ( $document_number == 1 ? '' : 's' );
    return 1;
}

sub _run_with_cache {

    my ( $self, $reader, $number_of_blocks, $number_of_documents ) = @_;
    my $document_number = 0;

    while ( my $document = $reader->next_document_for_this_job() ) {
        $document_number++;
        my $doc_name = $document->full_filename;
        my $doc_from = $document->loaded_from;
        log_info "Document $document_number/$number_of_documents $doc_name loaded from $doc_from";
        my $block_number       = 0;
        my $skip_to            = 0;
        my $process            = 0;
        my $skip_from          = 0;
        my $skip_from_last     = 0;
        my $from_hash          = "";
        my $from_hash_last     = "";
        my $initial_hash       = $document->get_hash();
        my $document_last_hash = "";
        foreach my $block ( @{ $self->loaded_blocks } ) {
            $block_number++;
            $process = 1;
            if ( $block_number < $skip_to ) {

                # we know that there are identical, so we can skip them
                log_info "Skipping block $block_number/$number_of_blocks " . ref($block);
                $process = 0;
            }
            elsif ( $block_number == $skip_to ) {

                # this is border Cache block -> we have to check whether next sequence is also same
                $skip_from = $block_number + 1;

                # following sequence is same => we can continue with skipping
                if ($sequence{$skip_from}{'to'}
                    &&
                    $self->_is_known_sequence( $sequence{$skip_from}{'hash'}, $document->get_hash() )
                    )
                {

                    #log_warn("\tskip from " . $sequence{$skip_from}{from} . ' to ' . $sequence{$skip_from}{to});
                    $skip_to   = $sequence{$skip_from}{to} - 1;
                    $from_hash = $document->get_hash();
                    $process   = 0;
                }
                else {
                    $document_last_hash = $document->get_hash();

                    #$document->set_hash(md5_hex($document->get_hash() . $block->get_hash()));
                    my $full_hash = $document->get_hash();
                    $document = $self->cache->get($full_hash);

                    if ( !$document ) {
                        log_fatal("Document - $full_hash is missing!!!");
                    }
                    $process = 2;
                }
            }

            if ( $process == 1 ) {
                log_info "Applying block $block_number/$number_of_blocks " . ref($block);

                $block->process_start if ( !$block->is_started );

                #log_info("Document-hash: " . $document->get_hash());
                $skip_from = $block_number + 1;
                my $status = $block->process_document($document);
                if (defined($status)
                    &&
                    $status == $Treex::Core::Block::DOCUMENT_FROM_CACHE &&
                    $sequence{$skip_from}{'to'} &&
                    $self->_is_known_sequence( $sequence{$skip_from}{'hash'}, $document->get_hash() )
                    )
                {

                    #log_warn("\tskip from " . $sequence{$skip_from}{from} . ' to ' . $sequence{$skip_from}{to});
                    $skip_to   = $sequence{$skip_from}{to} - 1;
                    $skip_from = $block_number + 1;
                    $from_hash = $document->get_hash();
                }
            }

            $document_last_hash = $document->get_hash();
            $document->set_hash( md5_hex( $document->get_hash() . $block->get_hash() ) );

            if ( ref($block) eq "Treex::Core::CacheBlock" ) {

                # cache block => mark this path as known
                my $id   = $block_number + 1;
                my $from = $sequence{$id}{'_from'};

                # the first sequence has no document
                if ( defined( $sequence{$from}{'document'} ) ) {
                    $self->_set_known_sequence( $sequence{$from}{'hash'}, $sequence{$from}{'document'} );
                }

                $sequence{$id}{'document'} = $document_last_hash;
            }
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
        $block->process_end() if ( $block->is_started );
    }

    return $document_number;
}

sub _is_known_sequence {
    my ( $self, $sequence_hash, $document_hash ) = @_;
    my $hash = md5_hex( $sequence_hash, $document_hash );
    return $self->cache->get($hash);
}

sub _set_known_sequence {
    my ( $self, $sequence_hash, $document_hash ) = @_;
    my $hash = md5_hex( $sequence_hash, $document_hash );
    $self->cache->set( $hash, 1 );

    return;
}

sub _run_without_cache {

    my ( $self, $reader, $number_of_blocks, $number_of_documents ) = @_;
    my $document_number = 0;

    $self->start();

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

    $self->end();

    log_info "Processed $document_number document"
        . ( $document_number == 1 ? '' : 's' );

    return $document_number;
}

# Apply process_start to all blocks for which this has not yet been applied
sub start {
    my ($self) = @_;

    log_info "Applying process_start";
    foreach my $block ( @{ $self->loaded_blocks } ) {
        $block->process_start() if ( !$block->is_started );
    }

    return;
}

# Apply the scenario to documents given in parameter
sub apply_to_documents {

    my ( $self, @documents ) = @_;

    my $number_of_blocks = @{ $self->loaded_blocks };
    my $block_number = 0;

    foreach my $document (@documents){
        log_info "Processing document" . $document->full_filename;

        foreach my $block ( @{ $self->loaded_blocks } ) {
            $block_number++;
            log_info "Applying block $block_number/$number_of_blocks " . ref($block);
            $block->process_document($document);
        }
    }

    return;
}

# Apply process_end to all blocks for which this has not yet been applied
sub end {
    my ($self) = @_;

    log_info "Applying process_end";
    foreach my $block ( @{ $self->loaded_blocks } ) {
        $block->process_end() if ( $block->is_started );
    }

    return;
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

 my $doc1, $doc2;
 my $scenario = Treex::Core::Scenario->new(from_file => 'myscenario.scen' );
 $scenario->run;


 $scenario = Treex::Core::Scenario->new(from_string => 'W2A::EN::Segment language=en');
 $scenario->start();
 $scenario->apply_to_documents($doc1, $doc2);
 $scenario->end();


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

=item $scenario->apply_to_documents($treex_doc);

Apply this scenario to a L<Treex::Core::Document> instance obtained from elsewhere.
Please note that C<start()> must be called before the first call to this method and C<end()>
after the last call to this method.

The scenario does not need to contain a document reader if documents are given
explicitly.

=item $scenario->start();

Apply C<process_start()> to all blocks in the scenario.
This is called automatically by C<run()>, but must be called before C<apply_to_documents()>.

=item $scenario->end();

Apply C<process_end()> to all blocks in the scenario.
This is called automatically by C<run()>, but must be called after calls to C<apply_to_documents()>.


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

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
