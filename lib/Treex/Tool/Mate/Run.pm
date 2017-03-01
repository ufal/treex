package Treex::Tool::Mate::Run;

use Moose;
use File::Temp qw(tempfile);

use Treex::Core::Common;
use Treex::Core::Resource;
use Treex::Tool::ProcessUtils;
use utf8;

# These are required to access the lang and sel from the caller block
has selector => ( is => 'ro', isa => 'Str', required => 1 );
has language => ( is => 'ro', isa => 'Str', required => 1 );

has model => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1
);

has memory => (
    is          => 'rw',
    isa         => 'Str',
    default     => '2G'
);

has classpath => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1
);

has classname => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1
);

has tmp_dir => (
    is          => 'ro',
    isa         => 'Str',
    default     => '/tmp',
    documentation   => 'directory, where the tmp input files are stored'
);

has is_lemmatized => (
    is          => 'ro',
    isa         => 'Bool',
    default     => 0,
    documentation   => 'Was the sentence lemmatized?'
);

has is_tagged => (
    is          => 'ro',
    isa         => 'Bool',
    default     => 0,
    documentation   => 'Was the sentence tagged?'
);

has is_mtagged => (
    is          => 'ro',
    isa         => 'Bool',
    default     => 0,
    documentation   => 'Was the sentence morphologically tagged?'
);

sub BUILD {
    my ($self) = @_;

#    my $tool_path = 'installed_tools/mate';
#    my $model_root = 'data/models/mate';
#    my $classpath = require_file_from_share("$tool_path/" . $self->classpath);
#    my $class = $self->classname;
#    my $model_path = require_file_from_share("$model_root/" . $self->model);
#    my $mem = $self->memory;

    # TODO: How to replace /dev/stdin and /dev/stdout on Windows (use NamedPipes, CONIN/CON)?
#    my $command = "java -Xmx$mem -classpath $classpath $class -test /dev/stdin -out /dev/stdout -model $model_path";
#    log_debug("COMMAND: $command");

    #$SIG{PIPE} = 'IGNORE';
#    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe( $command, ":encoding(UTF-8)" );

#    $self->{reader} = $reader;
#    $self->{writer} = $writer;
#    $self->{pid}    = $pid;

    return; 
}

sub process_document {
    my ( $self, $doc ) = @_;

    my ($tmp_fh, $tmp_filename) = tempfile("mate.XXXXX", DIR => $self->tmp_dir, UNLINK => 1);
    binmode($tmp_fh, ":encoding(UTF-8)");

    my @bundles = $doc->get_bundles();
    foreach my $bundle (@bundles) {
        my $zone = $bundle->get_zone($self->language(), $self->selector());
        
        my $a_root;
        if ($zone->has_atree) {
            $a_root = $zone->get_atree();
        }
        else {
            $a_root = $zone->create_atree();
            my $ord = 1;

            # We assume, that the sentence has already been tokenized
            foreach my $token (split / /, $zone->sentence) {
                $a_root->create_child( form => $token, ord => $ord );
                $ord++;
            }
        }
        my $input_string = $self->_prepare_input($a_root);
        print $tmp_fh "$input_string\n";
    }
    $tmp_fh->flush();

    my $output_str = $self->_run_command($tmp_filename);
    $output_str =~ s/\n\n$//s;
    my @sentence_strings = split /\n\n/, $output_str;

    my $iterator = List::MoreUtils::each_arrayref(\@bundles, \@sentence_strings);
    while (my ($bundle, $sent_str) = $iterator->() ) {
        my $zone = $bundle->get_zone($self->language(), $self->selector());
        
        my $a_root = $zone->get_atree();
        $self->_process_output($a_root, $sent_str);
    }

    return;
}

sub process_sentence {
    my ($self, $a_root) = @_;

    my $input_string = $self->_prepare_input($a_root);
    my ($tmp_fh, $tmp_filename) = tempfile("mate.XXXXX", DIR => $self->tmp_dir, UNLINK => 1);
    binmode($tmp_fh, ":encoding(UTF-8)");
    print $tmp_fh "$input_string";
    $tmp_fh->flush();

    my $output_str = $self->_run_command($tmp_filename);
    $self->_process_output($a_root, $output_str);
}

sub _prepare_input {
    my ($self, $a_root) = @_;

    my $result = "";
    my @nodes = $a_root->get_descendants( { ordered => 1 } );
    foreach my $node (@nodes) {
        $result .= $self->_write_line_conll2009($node) . "\n";
    }

    return $result;
}

# This is similar to the Block::Write::CoNLL2009
sub _write_line_conll2009 {
    my ($self, $a_node) = @_;

    my $lemma = defined $a_node->lemma ? $a_node->lemma : "_";
    my $pos = defined $a_node->get_attr("conll/pos") ? $a_node->get_attr("conll/pos") : "_";
    $pos = $a_node->tag if ($pos eq "_" && defined $a_node->tag);
#    my $cpos = defined$a_node->get_attr("conll/cpos") ? $a_node->get_attr("conll/cpos") : "_";
    my $deprel = defined $a_node->get_attr("conll/deprel") ? $a_node->get_attr("conll/deprel") : "_";
    $deprel = $a_node->afun if ($pos eq "_" && defined $a_node->afun);
    my $feat = defined$a_node->get_attr("conll/feat") ? $a_node->get_attr("conll/feat") : "_";
    my $p_ord = $a_node->get_parent->ord;

    # TODO: add prefixes to afuns?

    my @line_arr = ($a_node->ord,$a_node->form,$lemma,"_",$pos,"_",$feat,"_",$p_ord,"_",$deprel,"_","_","_","_");

    return join "\t", @line_arr;
}

sub _run_command {
    my ($self, $input) = @_;

    my $tool_path = 'installed_tools/mate';
    my $model_root = 'data/models/mate';
    my $classpath = require_file_from_share("$tool_path/" . $self->classpath);
    my $class = $self->classname;
    my $model_path = require_file_from_share("$model_root/" . $self->model);
    my $mem = $self->memory;

    # Processing information are printed to stdout as default, so we drop them like this
    my $command = "java -Xmx$mem -classpath $classpath $class -test $input -out /dev/stderr -model $model_path 2>&1 > /dev/null";
    log_debug("COMMAND: $command");

    #$SIG{PIPE} = 'IGNORE';
    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe( $command, ":encoding(UTF-8)" );

    my $result = "";
    while(<$reader>) {
        chomp;
        $result .= "$_\n";
    }

    # This is an ugly hack. The way we are getting output (from /dev/stdout)
    # results in getting processing info mixed in our result string
    # (We might try sending the result through stderr instead?)
    log_debug("RESULT_STRING: $result");
 
    return $result;
}

sub _process_output {
    my ($self, $a_root, $output_str) = @_;

    my @nodes = $a_root->get_descendants( { ordered => 1 } );
    my @output_arr = split /\n/, $output_str;

    my $iterator = List::MoreUtils::each_arrayref(\@nodes, \@output_arr);
    while (my ($node, $line) = $iterator->() ) {
        $self->_read_line_conll2009($node, \@nodes, $line);
    }
    
    return;
}

# This is similar to the Block::Read::CoNLL2009
sub _read_line_conll2009 {
    my ($self, $a_node, $parents, $line) = @_;

    my ( $id, $form, $lemma, $plemma, $postag, $ppos, $feats, $pfeat, $head, $phead, $deprel, $pdeprel ) = split( /\s+/, $line);
    
    log_warn("Node IDs do not match. Original: " . $a_node->ord . ", returned: $id.") if ($a_node->ord ne $id);

    # The mate-tools produce the non-gold CoNLL categories
    # TODO: this should probably be changed to correspond to the CoNLL2009 definition
    $a_node->set_lemma($plemma) if !$self->is_lemmatized;
    $a_node->set_tag($ppos);
    $a_node->set_conll_cpos($ppos);
    $a_node->set_conll_pos($ppos);
    $a_node->set_conll_feat($pfeat);
    $a_node->set_conll_deprel($pdeprel);

    $a_node->set_parent($parents->[$phead - 1]) if ($phead > 0);

    return;
}

1;

=head1 NAME

Treex::Tool::Mate::Run -- wrapper for mate-tools Java implementation

=head1 DESCRIPTION

The tool expects at least flat a-tree as an input.

#TODO

=head1 PARAMETERS

=head1 TODO

Support for Windows platforms.

=over

=back

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
