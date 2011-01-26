package Treex::Core::Scenario;
use Moose;
use MooseX::SemiAffordanceAccessor;

has loaded_blocks => ( is => 'ro', isa => 'ArrayRef[Treex::Core::Block]', default => sub {[]});

has document_reader => ( is => 'rw', does => 'Treex::Core::DocumentReader',
            documentation => 'DocumentReader starts every scenario and reads a stream of documents.' );

use Report;
use File::Basename;
use Treex::Core::Document;

my $TMT_DEBUG_MEMORY = ( defined $ENV{TMT_DEBUG_MEMORY} and $ENV{TMT_DEBUG_MEMORY} );

sub BUILD {
    my ( $self, $arg_ref ) = @_;

    Report::memory if $TMT_DEBUG_MEMORY;

    Report::info("Initializing an instance of TectoMT::Scenario ...");

    #<<< no perltidy
    my $scen_str = defined $arg_ref->{from_file} ? load_scenario_file($arg_ref->{from_file})
                 :                                 $arg_ref->{from_string};
    #>>>
    Report::fatal 'No blocks specified for a scenario!' if !defined $scen_str;

    my @block_items = parse_scenario_string( $scen_str, $arg_ref->{from_file} );
    my $blocks = @block_items;
    Report::fatal('Empty block sequence cannot be used for initializing scenario!') if $blocks == 0;

    Report::memory if $TMT_DEBUG_MEMORY;

    Report::info( "$blocks block" . ( $blocks > 1 ? 's' : '' ) . " to be used in the scenario:\n" );

    # loading (using modules and constructing instances) of the blocks in the sequence
    foreach my $block_item (@block_items) {
        my $block_name = $block_item->{block_name};
        eval "use $block_name;";
        Report::fatal "Can't use block $block_name !\n$@\n" if $@;
    }

    my $i = 0;
    foreach my $block_item (@block_items) {
        $i++;
        my $params = '';
        if ( $block_item->{block_parameters} ) {
            $params = join ' ', @{ $block_item->{block_parameters} };
        }
        Report::info("Loading block $block_item->{block_name} ($i/$blocks) $params...");
        my $new_block = _load_block($block_item);
        
        if ($new_block->does('Treex::Core::DocumentReader')){
            Report::fatal("Only one DocumentReader per scenario is permitted ($block_item->{block_name})")
                if $self->document_reader();
            $self->set_document_reader($new_block);
        } else {
            push @{ $self->loaded_blocks }, $new_block;
        }
    }

    Report::info('');
    Report::info('   ALL BLOCKS SUCCESSFULLY LOADED.');
    Report::info('');
    return;
}

sub load_scenario_file {
    my ($scenario_filename) = @_;
    Report::info "Loading scenario description $scenario_filename";
    open my $SCEN, '<:utf8', $scenario_filename or
        Report::fatal "Can't open scenario file $scenario_filename";
    my $scenario_string = join ' ', <$SCEN>;
    close $SCEN;
    return $scenario_string;
}

sub _escape {
    my $string = shift;
    $string =~ s/ /%20/g;
    $string =~ s/#/%23/g;
    return $string;
}

sub parse_scenario_string {
    my ( $scenario_string, $from_file ) = @_;

    # Preserve escaped quotes
    $scenario_string =~ s{\\"}{%22}g;
    $scenario_string =~ s{\\'}{%27}g;

    # Preserve spaces inside quotes and backticks in block parameters
    # Quotes are deleted, whereas backticks are preserved.
    $scenario_string =~ s/="([^"]*)"/'='._escape($1)/eg;
    $scenario_string =~ s/='([^']*)'/'='._escape($1)/eg;
    $scenario_string =~ s/(=`[^`]*`)/_escape($1)/eg;

    $scenario_string =~ s/#.+?\n//g;
    $scenario_string =~ s/#.+$//;      #comment on last line
    $scenario_string =~ s/\s+/ /g;
    $scenario_string =~ s/^ //g;
    $scenario_string =~ s/ $//g;

    my @tokens = split / /, $scenario_string;
    my @block_items;
    foreach my $token (@tokens) {

        # include of another scenario file
        if ( $token =~ /\.scen/) {
            my $scenario_filename = $token;
            $scenario_filename =~ s/\$\{?TMT_ROOT\}?/$ENV{TMT_ROOT}/;

            my $included_scen_path;
            if ( $scenario_filename =~ m|^/| ) {    # absolute path
                $included_scen_path = $scenario_filename
            }
            elsif ( defined $from_file ) {          # relative to the "parent" scenario file
                $included_scen_path = dirname($from_file) . "/$scenario_filename";
            }
            else {                                  # relative to the cwd
                $included_scen_path = "./$scenario_filename";
            }

            my $included_scen_str = load_scenario_file($included_scen_path);
            push @block_items, parse_scenario_string( $included_scen_str, $included_scen_path );
        }

        # parameter definition
        elsif ( $token =~ /(\S+)=(\S+)/ ) {
            my ( $param_name, $param_value ) = ( $1, $2 );

            # "de-escape"
            $token =~ s/%20/ /g;
            $token =~ s/%23/#/g;
            $token =~ s/%22/"/g;
            $token =~ s/%27/'/g;

            if ( not @block_items ) {
                Report::fatal "Specification of block arguments before the first block name: $token\n";
            }
            push @{ $block_items[-1]->{block_parameters} }, $token;
        }

        # block definition
        else {
            my $block_filename = $token;
            $block_filename =~ s/::/\//g;
            $block_filename .= '.pm';
            if ( -e $ENV{TMT_ROOT} . "/treex/lib/Treex/Block/$block_filename" ) {  # new Treex blocks
                $token = "Treex::Block::$token";
            } elsif ( -e $ENV{TMT_ROOT} . "/libs/blocks/$block_filename" ) {       # old TectoMT blocks
            } else {
                # TODO allow user-made blocks not-starting with Treex::Block?
                Report::fatal("Block $token (file $block_filename) does not exist!");
            }
            push @block_items, { 'block_name' => $token, 'block_parameters' => [] };
        }
    }

    return @block_items;
}

# reverse of parse_scenario_string, used in tools/tests/auto_diagnose.pl
sub construct_scenario_string {
    my ( $block_items, $multiline ) = @_;
    return join(
        $multiline ? "\n" : ' ',
        map {
            $_->{block_name} . " " . join( " ", @{ $_->{block_parameters} } )
            } @$block_items
    );
}

sub _load_block {
    my ($block_item) = @_;
    my $block_name = $block_item->{block_name};

    # constructing the block instance (possibly parametrized)
    my $constructor_parameters = join ",",
        map {
        my ( $name, $value ) = split /=/;
        "q($name)=>q($value)"
        } @{ $block_item->{block_parameters} };

    my $new_block;
    my $string_to_eval = '$new_block = ' . $block_name . "->new({$constructor_parameters});";
    eval $string_to_eval;
    if ($@) {
        Report::fatal "Treex::Core::Scenario->new: error when initializing block $block_name by evaluating '$string_to_eval'\n" . $!;
    }

    Report::memory if $TMT_DEBUG_MEMORY;

    return $new_block;
}

sub run {
    my ( $self ) = @_;
    my $reader = $self->document_reader or Report::fatal('No DocumentReader supplied');
    my $number_of_blocks  = @{ $self->loaded_blocks };
    my $document_number = 0;
    
    while (my $document = $reader->next_document()) {
        $document_number++;
        Report::info "Document $document_number loaded";
        my $block_number = 0;
        foreach my $block ( @{$self->loaded_blocks} ) {
            $block_number++;
            Report::info "Applying block $block_number/$number_of_blocks " . ref($block);
                #TODO . ( defined $filename ? " on '$filename'" : '' );
            $block->process_document($document);
        }
    }
    Report::info "Processed $document_number document"
        . ($document_number>1 ? 's' : '');
    return;
}

1;

__END__

=head1 NAME

Treex::Core::Scenario

=head1 SYNOPSIS

 use Treex::Core::Scenario;
 ??? ??? ??? ???



=head1 DESCRIPTION


?? ?? ?? ?? ?? ???? ?? ???? ?? ???? ?? ?? needs to be updated


=head1 METHODS

=head2 Constructor

=over 4

=item BUILD

The real constructor that should not be called directly.

=item my $scenario = Treex::Core::Scenario->new(scen => 'W2A::Tokenize language=en  W2A::Lemmatize' );

Constructor parameter 'scen' specifies
the names of blocks which are to be executed (in the specified order)
when the scenario is applied on a Treex::Core::Document object.

=back


=head2 Running the scenario

=over 4

=item $scenario->apply_on_stream($stream);

It applies the blocks on a stream of treex documents.

=back

=head2 Rather internal methods for loading scenarios

=over 4

=item construct_scenario_string

=item load_scenario_file

=item parse_scenario_string

=back


=head1 SEE ALSO

L<TectoMT::Node|TectoMT::Node>,
L<TectoMT::Bundle|TectoMT::Bundle>,
L<Treex::Core::Document|Treex::Core::Document>,
L<TectoMT::Block|TectoMT::Block>,


=head1 AUTHORS

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright 2006-2010 Zdenek Zabokrtsky, Martin Popel.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

