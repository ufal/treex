package Treex::Core::Scenario;

our $VERSION = '0.1';

use Moose;
use MooseX::FollowPBP;

has block_sequence => (is => 'rw');
has loaded_modules => (is => 'rw');

use vars qw($root $this $grp $SelectedTree);

use Report;

use File::Basename;

use Treex::Core::Document;

my @backends = (); # tentative, just to avoid error messages !!!


my $TMT_DEBUG_MEMORY = ( defined $ENV{TMT_DEBUG_MEMORY} and $ENV{TMT_DEBUG_MEMORY} );


    sub BUILD {
        my ( $self, $arg_ref ) = @_;

        Report::memory if $TMT_DEBUG_MEMORY;

        Report::info("Initializing an instance of TectoMT::Scenario ...");

        #<<< no perltidy
        my $scen_str = defined $arg_ref->{blocks}    ? join ' ', @{ $arg_ref->{blocks} }
                     : defined $arg_ref->{from_file} ? load_scenario_file($arg_ref->{from_file})
                     :                                 $arg_ref->{from_string};
        #>>>
        Report::fatal 'No blocks specified for a scenario!' if !defined $scen_str;

        my @block_items = parse_scenario_string( $scen_str, $arg_ref->{from_file} );
        my $blocks = @block_items;
        Report::fatal('Empty block sequence cannot be used for initializing scenario!') if $blocks == 0;

        Report::memory if $TMT_DEBUG_MEMORY;

        Report::info( "$blocks block" . ( $blocks > 1 ? 's' : '' ) . " to be used in the scenario:\n" );

        # loading (using modules and constructing instances) of the blocks in the sequence
        my $i = 0;
        my $blocks_to_skip;
        my @blocks_to_use;

        foreach my $block_item (@block_items) {
            _check_block($block_item);
        }

        foreach my $block_item (@block_items) {
            $i++;
            my $params = '';
            if ( exists $block_item->{skipblocks} ) {
                $blocks_to_skip = $block_item->{skipblocks};
                Report::info "Scenario instruction ($i/$blocks): skip $blocks_to_skip following block(s).";
            }
            elsif ($blocks_to_skip) {
                $blocks_to_skip--;
                Report::info("Skipping block $block_item->{block_name} ($i/$blocks).");
            }
            else {
                if ( $block_item->{block_parameters} ) {
                    $params = join ' ', @{ $block_item->{block_parameters} };
                }
                Report::info("Loading block $block_item->{block_name} ($i/$blocks) $params...");
                my $new_block = _load_block($block_item);
                push @{ $self->{block_sequence} }, $new_block;
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

            # !!! tohle je tu jen docasne, kvuli kompatibilite se starym zapisem scenaru
            next if $token =~ /^!/;

            # include of another scenario file
            if ( $token =~ /^include\((.+)\)/ ) {
                my $scenario_filename = $1;
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

                    #Report::fatal( '"include" can be used only in scenarios saved in files: ' . $token )
                }

                my $included_scen_str = load_scenario_file($included_scen_path);
                push @block_items, parse_scenario_string( $included_scen_str, $included_scen_path );
            }

            # block definition
            elsif ( $token =~ /\S+::\S+/ ) {
                push @block_items, { 'block_name' => $token, 'block_parameters' => [] };
            }

            # parameter definition
            elsif ( $token =~ /(\S+)=(\S+)/ ) {
                my ( $param_name, $param_value ) = ( $1, $2 );

                # "de-escape"
                $token =~ s/%20/ /g;
                $token =~ s/%23/#/g;
                $token =~ s/%22/"/g;
                $token =~ s/%27/'/g;

                # !!! tohle je tu jen docasne, kvuli kompatibilite se starym zapisem scenaru
                if ( $param_name =~ /^TMT_PARAM/ ) {
                    Report::info "Block paramater $param_name stored also as system variable.";
                    $ENV{$param_name} = $param_value;
                }

                if ( not @block_items ) {
                    Report::fatal "Specification of block arguments before the first block name: $token\n";
                }
                push @{ $block_items[-1]->{block_parameters} }, $token;
            }

            # skipping instructions
            elsif ( $token =~ /skipblocks\((\d+)\)/ ) {
                push @block_items, { 'skipblocks' => $1 };
            }

            else {
                Report::fatal 'Unrecognized expression (not a block, not a parameter)'
                    . " in scenario description: $token";
            }
        }

        return @block_items;
    }

    # reverse of parse_scenario_string, used in tools/tests/auto_diagnose.pl
    sub construct_scenario_string {       
        my ($block_items, $multiline) = @_;
        return join(
            $multiline ? "\n" : ' ',
            map {
                $_->{block_name} . " " . join( " ", @{ $_->{block_parameters} } )
                } @$block_items
        );
    }
    
    # turn one scenario definition line into a block object
    sub construct_block {
    	my ($block_item) = @_;
    	_check_block($block_item);
    	return _load_block($block_item);
    }

    sub _check_block {
        my ($block_item) = @_;
        my $block_name = $block_item->{block_name};

        my $block_filename = $block_name;
        $block_filename =~ s/::/\//g;
        $block_filename .= '.pm';

        if (( not -e $ENV{TMT_ROOT} . "/libs/blocks/$block_filename" ) && ( not -e $ENV{TMT_ROOT}."/treex/lib/$block_filename")) {
            Report::fatal("Block $block_name (file $block_filename) does not exist!");
        }

        eval "use $block_name;";
        if ($@) {
            Report::fatal "Can't use block $block_name !";
        }
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
            Report::fatal "TectoMT::Scenario->new: error when initializing block $block_name by evaluating '$string_to_eval'\n" . $!;
        }

        Report::memory if $TMT_DEBUG_MEMORY;

        return $new_block;
    }

    sub apply_on_stream {
        my ( $self, $stream ) = @_;

      STREAMLOOP:
        while (1) {
            print "Staring loop\n";
            foreach my $block ( @{ $self->get_block_sequence } ) {
                print "Running block " . ref($block) . "\n";
                $block->process_stream($stream) or last STREAMLOOP;
            }
        }
    }


    sub apply_on_tmt_documents {
        my $self      = shift @_;
        my @documents = @_;

        print "Documents: ". (join " ", @documents)."\n";

        if ( @documents == 0 ) {
            Report::fatal "No document specified";
        }
        elsif ( my ($nonvalid) = grep { not UNIVERSAL::isa( $_, "Treex::Core::Document" ) } @documents ) {
            Report::fatal "Arguments must be instances of Treex::Core::Document, but it is $nonvalid";
        }

        my $block_number = 0;
        my $block_total  = @{ $self->get_block_sequence };
        my $doc_total    = @documents;
        foreach my $block ( @{ $self->get_block_sequence } ) {
            $block_number++;
            my $doc_number = 0;
            foreach my $document (@documents) {
                $doc_number++;
                my $filename = $document->filename();
                $filename = basename($filename) if defined $filename;

                Report::info "Applying block $block_number/$block_total " . ref($block)
                    . ( defined $filename ? " on '$filename'" : "" );

                $block->process_document($document);

                Report::memory if $TMT_DEBUG_MEMORY;
            }
        }
    }

    sub apply_on_tmt_files {
        my $self      = shift @_;
        my @filenames = @_;
        Report::info "Number of files to be processed by the scenario: " . scalar(@filenames) . " \n";
        foreach my $filename (@filenames) {
            Report::info "Processing $filename ...\n";
            my $fsfile = FSFile->newFSFile( $filename, "utf8", @backends );    # vykopirovano z btredu
            if ( not UNIVERSAL::isa( $fsfile, "FSFile" ) ) {
                Report::fatal "Did not succeed to open fsfile ($fsfile)";
            }
            my $document = Treex::Core::Document->new();
            $document->tie_with_fsfile($fsfile);
            $self->apply_on_tmt_documents($document);
            Report::info "Saving $filename ...\n";
            $fsfile->writeFile($filename);

        }

    }

    sub apply_on_tmt_files_without_save {    # ??? praseci, potreba nahradit parametrem konstruktoru!!!
        my $self      = shift @_;
        my @filenames = @_;
        Report::info "Number of files to be processed by the scenario: " . scalar(@filenames) . " \n";
        foreach my $filename (@filenames) {
            Report::info "Processing $filename ...\n";
            my $fsfile = FSFile->newFSFile( $filename, "utf8", @backends );    # vykopirovano z btredu
            if ( not UNIVERSAL::isa( $fsfile, "FSFile" ) ) {
                Report::fatal "Did not succeed to open fsfile ($fsfile)";
            }
            my $document = Treex::Core::Document->new();
            $document->tie_with_fsfile($fsfile);
            $self->apply_on_tmt_documents($document);
        }
        return;
    }

    sub apply_on_fsfile_objects {
        my $self    = shift;
        my @fsfiles = @_;
        if ( grep { not UNIVERSAL::isa( $_, "FSFile" ) } @fsfiles ) {
            Report::fatal "Arguments must be FSFile instances.";
        }

        my @untied_fsfiles = grep { not defined( $Treex::Core::Document::fsfile2tmt_document{$_} ) } @fsfiles;

        my @tmt_documents;
        if (@untied_fsfiles) {
            Report::debug( 'There are fsfiles without associated TectoMT representation, which is therefore being built now.', 1 );
            foreach my $fsfile (@untied_fsfiles) {
                push @tmt_documents, Treex::Core::Document->new( { 'fsfile' => $fsfile } );
            }
        }

        $self->apply_on_tmt_documents(@tmt_documents);

    }



1;

__END__

=head1 NAME

Treex::Core::Scenario


=head1 VERSION

0.0.2

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

=item my $scenario = Treex::Core::Scenario->new({'blocks'=> [ qw(Blocks::Tokenize  Blocks::Lemmatize) ]);

Constructor argument is a reference to a hash containing options. Option 'blocks' specifies
the reference to the array of names of blocks which are to be executed (in the specified order)
when the scenario is applied on a Treex::Core::Document object.

=back



=head2 Running the scenario

=over 4

=item $scenario->apply_on_tmt_documents(@documents);

Applies the sequence of blocks on the specified Treex::Core::Document objects.

=item $scenario->apply_on_tmt_files(@file_names);

Opens the PML files (corresponding instances of Treex::Core::Documents), applies the
translation blocks on them, and saves the files back (under the same names).

=item $scenario->apply_on_tmt_files_without_save(@file_names);

=item $scenario->apply_on_fsfile_objects(@fsfiles);

It applies the blocks on the given list of instances of class FSFile
(e.g. $grp->{FSFile} in btred/ntred)

=item $scenario->apply_on_stream($stream);

It applies the blocks on a stream of treex documents.

=back

=head2 Rather internal methods for loading scenarios

=over 4

=item construct_block

=item construct_scenario_string

=item load_scenario_file

=item parse_scenario_string

=back


=head1 SEE ALSO

L<TectoMT::Node|TectoMT::Node>,
L<TectoMT::Bundle|TectoMT::Bundle>,
L<Treex::Core::Document|Treex::Core::Document>,
L<TectoMT::Block|TectoMT::Block>,


=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright 2006-2009 Zdenek Zabokrtsky, Martin Popel.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

