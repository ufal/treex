package Treex::Tool::Phrase2Dep::StanfordConverter;
use Moose;
use Treex::Core::Common;
use File::Temp;
use File::Slurp;
use Treex::Tool::ProcessUtils;

has language => ( isa => 'Str', is => 'rw', required => 1, default => 'en', );
has tmpdir => ( isa => 'Str', is => 'rw' );

sub BUILD {
    my ($self) = @_;
    $self->set_tmpdir(
        File::Temp::tempdir( 'parser_XXXXXXX', DIR => Treex::Core::Config->tmp_dir() )    #, CLEANUP => 1
    );
    log_info "Temporary directory for a phrase-structure parser: " . $self->tmpdir . "\n";
    return;
}


sub run_converter {
    my ($self)  = @_;
    my $tmpdir  = $self->tmpdir;

	my $TOOL_DIR = "$ENV{TMT_ROOT}/share/installed_tools/parser/stanford-parser-2011-09-14";
	my $JAR      = 'stanford-parser.jar';
    my $jar = "$TOOL_DIR/$JAR";

    my $command = " java -Xms100m -cp $jar edu.stanford.nlp.trees.EnglishGrammaticalStructure";
    $command .= " -basic";
    $command .= " -conllx";
    $command .= " -keepPunct";
    $command .= " -makeCopulaHead";
    $command .= " -treeFile $tmpdir/input.txt >$tmpdir/output.txt 2>$tmpdir/stderr.txt";
#     $command .= " -filter";

    Treex::Tool::ProcessUtils::safesystem($command);
    return;
}




sub prepare_converter_input {

    my ( $self, $zones_rf ) = @_;

    open my $INPUT, ">:encoding(UTF-8)", $self->tmpdir . "/input.txt" or log_fatal $!;


    foreach my $zone (@$zones_rf) {


		my $ptree = $zone->get_ptree();
		my ( $a_root, @a_nodes );
		if ( $zone->has_atree ) {
			$a_root = $zone->get_atree();
			@a_nodes = $a_root->get_descendants( { ordered => 1 } );
		}
		else {
			$a_root  = $zone->create_atree();
			@a_nodes = ();
			my $ord = 1;
			foreach my $terminal ( grep { $_->form } $ptree->get_descendants() ) {

				# skip traces
				next if $terminal->tag =~ /-NONE-/;
				push @a_nodes, $a_root->create_child(
					{
						form  => $terminal->form,
						lemma => $terminal->lemma,
						tag   => $terminal->tag,
						ord   => $ord++,
					}
				);
			}
		}

		my $mrg_string = $ptree->stringify_as_mrg() . "\n";
		
		print $INPUT $mrg_string;
	}


    close $INPUT;

    return;
}


sub process_converter_output {
     my ( $self, $zones_rf ) = @_;

    my $out_filename = $self->tmpdir . '/output.txt';
    log_fatal "The converter did not create $out_filename" if !-f $out_filename;
    my $output = read_file($out_filename) or log_fatal "Empty $out_filename ($!)";

	my @output = split /\n\n/, $output;

	my $i = 0;
    foreach my $zone (@$zones_rf) {
		my $a_root = $zone->get_atree();
		my @a_nodes = $a_root->get_descendants( { ordered => 1 } );
	
		my $one_sentence = $output[$i];

		$i++;

		my ( @parents, @deprels );
		foreach my $line (split /\n/, $one_sentence) {
			my @conll_columns = split /\t/, $line;
			push( @parents, $conll_columns[6] );
			push( @deprels, $conll_columns[7] );
		}



		log_fatal "Wrong number of nodes returned:\n"
	#        . "MRG_STRING=$mrg_string\n"
			. "PARENTS=" . Dumper(\@parents)
			. "DEPRELS=" . Dumper(\@deprels)
			. "ANODES=" . Dumper( [ map { $_->form } @a_nodes ] )
			if ( @parents != @a_nodes || @deprels != @a_nodes );

		# flatten so there are no temporary cycles introduced
		foreach my $a_node (@a_nodes) {
			$a_node->set_parent($a_root);
		}

		my @all_nodes = ( $a_root, @a_nodes );
		foreach my $a_node (@a_nodes) {
			$a_node->set_conll_deprel( shift @deprels );
			my $index = shift @parents;
			$a_node->set_parent( $all_nodes[$index] );
		}
	}

    return;

}


sub convert_zones {
    my ( $self, $zones_rf ) = @_;
    log_info( scalar(@$zones_rf) . " sentences to be parsed" );
    $self->prepare_converter_input($zones_rf);
    $self->run_converter();
    $self->process_converter_output($zones_rf); # ???
    return;
}


1;

__END__


=over

=item Treex::Tool::Phrase2Dep::StanfordConverter


=back

=cut

# Copyright 2011 Lenka Smejkalova <smejkalova@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

