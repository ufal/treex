package Treex::Block::Coref::EN::ResolveBART2;
use Moose;
use utf8;
use Treex::Core::Common;

use IPC::Run3;
use Treex::Tool::ProcessUtils;
use File::Temp;
use String::Diff;
use HTML::Entities;

extends 'Treex::Core::Block';
with 'Treex::Block::Coref::ResolveFromRawText';

has '_tmp_dir' => ( is => 'rw', isa => 'File::Temp::Dir' );
has '_bart_read' => ( is => 'rw', isa => 'FileHandle');
has '_bart_write' => ( is => 'rw', isa => 'FileHandle');
has '_bart_pid' => ( is => 'rw', isa => 'Int');


sub java_version {
    my ($java_cmd) = @_;
    my ($in, $out, $err);
    my $lines = run3("$java_cmd -version", \$in, \$out, \$err);
    my ($version) = grep {$_ =~ /^java version/} split /\n/, $err;
    $version =~ s/^[^"]*"//;
    $version =~ s/"[^"]*$//;
    return $version;
}

sub process_start {
    my ($self) = @_;
    
    my $dir = File::Temp->newdir("/COMP.TMP/bart.tmpdir.XXXXX");
    $self->_set_tmp_dir($dir);

    my $java_cmd = defined $ENV{JAVA_HOME} ? $ENV{JAVA_HOME}."/bin/java" : "java";
    my $java_version = java_version($java_cmd);
    if ($java_version !~ /^1\.7\..*/) {
        log_warn "BART 2 should be run on Java version 1.7.*. You are using the version $java_version. BART could not work properly. You can change it by modifying the enviroment variable JAVA_HOME."
    }

    my $command = "cd $dir;";
    my $cp = join ":", map {'/net/cluster/TMP/mnovak/tools/BART-2.0/' . $_} ("BART2_eclipse/BART.jar", "libs2/*");
    $command .= " $java_cmd -Xmx3072m -classpath \"$cp\" -Delkfed.rootDir='/net/cluster/TMP/mnovak/tools/BART-2.0' elkfed.webdemo.Demo";

    #log_info "Launching BART 2.0: $command";
    my ( $read, $write, $pid );
    eval {
        ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);
    };
    if ($@) {
        log_fatal $@;
    }

    while (my $line = <$read>) {
        chomp $line;
        last if ($line =~ /^<INIT_OK>/);
    }
    $self->_set_bart_read($read);
    $self->_set_bart_write($write);
    $self->_set_bart_pid($pid);
}

sub process_end {
    my ($self) = @_;
    log_info "Closing BART 2.0...";
    close( $self->_bart_write );
    close( $self->_bart_read );
    Treex::Tool::ProcessUtils::safewaitpid( $self->_bart_pid );
}

sub _process_bundle_block {
    my ($self, $block_id, $bundles) = @_;
    
    log_info "Processing bundle block $block_id ...";
    
    my @sentences = $self->_prepare_raw_text($bundles);

    foreach my $sent (@sentences) {
        my $ack;
        eval {
            print {$self->_bart_write} $sent;
            print {$self->_bart_write} "\n";
            my $read = $self->_bart_read; 
            $ack = <$read>;
        };
        if ($@) {
            log_fatal $@;
        }
        if ($ack !~ /^<LINE_OK>/) {
            log_info "SENTENCE: $sent";
            log_fatal "A problem occurred while reading an input by BART";
        }
    }
    print {$self->_bart_write} "\n";

    my $read = $self->_bart_read; 
    my @xml_lines;
    while (my $line = <$read>) {
        last if ($line =~ /^<DOC_FINISHED>/);
        push @xml_lines, $line;
    }

    my ($sents, $corefs) = _extract_info(\@xml_lines);
    my @atrees = map {$_->get_tree($self->language, "a", $self->selector)} @$bundles;
    my @all_nodes = map { [ $_->get_descendants({ordered => 1}) ] } @atrees;
    my @all_forms = map { [ map {my $form = $_->form; $form =~ s/\s*//g; $form} @$_ ] } @all_nodes;

    my $align = align_arrays_simple($sents, \@all_forms);

    #log_info Dumper($sents);
    #log_info Dumper($corefs);
    #log_info Dumper($align);

    for my $entity_id (keys %$corefs) {
        my $chain = $corefs->{$entity_id};
        my $ante = locate_mention_head(shift @$chain, $align, \@all_nodes);
        while (my $anaph = locate_mention_head(shift @$chain, $align, \@all_nodes)) {
            if (defined $ante && defined $anaph && !$ante->is_root && !$anaph->is_root) {
                $anaph->add_coref_text_nodes($ante);
                # print STDERR "ANAPH: " . $anaph->t_lemma . "\n";
            }
            $ante = $anaph;
        }
    }
}

sub _prepare_raw_text {
    my ($self, $bundles) = @_;
    
    my @sents = map {
        my $atree = $_->get_tree($self->language, "a", $self->selector);
        my $sent = join " ", map {$_->form} $atree->get_descendants({ordered => 1});
        $sent
    } @$bundles;
    return @sents;
}

sub locate_mention_head {
    my ($mention, $align, $anodes, $sents) = @_;

    return if (!defined $mention);

    my ($start_s, $start_w, $end_s, $end_w) = @$mention;

    #print STDERR "MENTION_BART: " . $sents->[$start_s][$start_w] . " .. " . $sents->[$end_s][$end_w] . " ($start_s, $start_w, $end_s, $end_w)\n";

    ($start_s, $start_w) = addr_bart_to_atree($start_s, $start_w, $align, 1);
    ($end_s, $end_w) = addr_bart_to_atree($end_s, $end_w, $align, 0);
    
    #print STDERR "MENTION_ATREE: " . $anodes->[$start_s][$start_w]->form . " .. " . $anodes->[$end_s][$end_w]->form . " ($start_s, $start_w, $end_s, $end_w)\n";

    my $start_anode = $anodes->[$start_s][$start_w];
    my ($start_tnode) = (
        $start_anode->get_referencing_nodes('a/lex.rf'),
        $start_anode->get_referencing_nodes('a/aux.rf')
    );

    my $head_tnode;
    if ($start_s != $end_s) {
        log_warn "Mention spans over multiple sentences: [$start_s, $start_w, $end_s, $end_w]:" . $start_tnode->get_address;
        $head_tnode = $start_tnode;
    }
    else {
        my $end_anode = $anodes->[$end_s][$end_w];
        my ($end_tnode) = (
            $end_anode->get_referencing_nodes('a/lex.rf'),
            $end_anode->get_referencing_nodes('a/aux.rf')
        );
        $head_tnode = _common_ancestor($start_tnode, $end_tnode);
    }
    return $head_tnode;
}

sub _common_ancestor {
    my ($node1, $node2) = @_;

    return $node1 if (!defined $node2);
    return $node2 if (!defined $node1);
    return $node1 if ($node1 == $node2);

    my $ances = $node2;

    while (defined $ances && !$node1->is_descendant_of($ances)) {
        $ances = $ances->parent;
    }

    return undef if (!defined $ances);
    return $ances;
}

sub _extract_info {
    my ($xml_lines) = @_;

    my @sents = ();
    my @sent_tokens = ();
    my %corefs = ();
    
    my $sent_idx = 0;
    my $word_idx = 0;
    my @active_coref = ();
    foreach my $line (@$xml_lines) {
        if ($line =~ /^<\/s>/) {
            $sent_idx++;
            $word_idx = 0;
            push @sents, [ @sent_tokens ];
            @sent_tokens = ();
        }
        elsif ($line =~ /^<coref set-id="set_([^"]*)">$/) {
            my $coref_start = [$sent_idx, $word_idx, $1];
            push @active_coref, $coref_start;
        }
        elsif ($line =~/^<\/coref>$/) {
            my $coref_start = pop @active_coref;
            my $mentions = $corefs{$coref_start->[2]} // [];
            push @$mentions, [$coref_start->[0], $coref_start->[1], $sent_idx, $word_idx - 1];
            $corefs{$coref_start->[2]} = $mentions;
        }
        elsif ($line =~ /^<w pos="[^"]*">([^<]*)<\/w>$/) {
            $word_idx++;
            push @sent_tokens, decode_entities($1);
        }
    }

    return (\@sents, \%corefs);
}

############### METHODS FOR ALIGNING TOKEN PRODUCED BY BART AND TREEX ###################
# TODO: this should be unified with the _align_arrays method in Coref::ResolveFromRawText

sub align_arrays_simple {
    my ($a1, $a2) = @_;
    
    my $joint_text_1 = join "", map {join "", @$_} @$a1;
    my $joint_text_2 = join "", map {join "", @$_} @$a2;
    
    if ($joint_text_1 ne $joint_text_2) {
        my $diff = String::Diff::diff($joint_text_1, $joint_text_2);
        print STDERR "$diff->[0]\n";
        print STDERR "$diff->[1]\n";
        return;
    }

    my $a1_to_idx = _build_a1_to_idx($a1);
    my $idx_to_a2 = _build_idx_to_a2($a2);
    #print STDERR Dumper($a1_to_idx);
    #print STDERR Dumper($idx_to_a2);
    
    return [ $a1_to_idx, $idx_to_a2, length($joint_text_1) ];
}

sub addr_bart_to_atree {
    my ($s, $w, $align, $is_start) = @_;

    my ($a1_to_idx, $idx_to_a2, $length) = @$align;
    
    my $idx;
    if ($is_start) {
        $idx = $a1_to_idx->[$s][$w];
    }
    else {
        $idx = $a1_to_idx->[$s][$w+1] // $a1_to_idx->[$s+1][0] // $length;
        $idx--;
    }

    my $a2_sw;
    while (!defined $a2_sw) {
        $a2_sw = $idx_to_a2->{$idx};
        $idx--;
    }

    return @$a2_sw;
}

sub _build_a1_to_idx {
    my ($a1) = @_;
    my $curr_idx = 0;
    my @a1_to_idx = ();
    foreach my $sent (@$a1) {
        my @word_idx = ();
        foreach my $word (@$sent) {
            push @word_idx, $curr_idx;
            $curr_idx += length $word;
        }
        push @a1_to_idx, \@word_idx;
    }
    return \@a1_to_idx;
}

sub _build_idx_to_a2 {
    my ($a2) = @_;
    my $curr_idx = 0;
    my %idx_to_a2 = ();
    for (my $i = 0; $i < @$a2; $i++) {
        my $sent = $a2->[$i];
        for (my $j = 0; $j < @$sent; $j++) {
            $idx_to_a2{$curr_idx} = [$i, $j];
            my $word = $a2->[$i][$j];
            $curr_idx += length $word;
        }
    }
    return \%idx_to_a2;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Coref::EN::ResolveBART2

=head1 DESCRIPTION

Coreference resolver for English wrapping BART 2 resolver.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
