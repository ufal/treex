package Treex::Block::Coref::EN::ResolveBART2;
use Moose;
use utf8;
use Treex::Core::Common;

use Treex::Tool::ProcessUtils;
use File::Temp;

extends 'Treex::Block::Coref::ResolveFromRawText';

sub process_document_one_zone_at_time {
    my ($self, $doc) = @_;

    my $tokenized_text = "";
    foreach my $bundle ($doc->get_bundles) {
        my $atree = $bundle->get_tree($self->language, "a", $self->selector);
        my $sent = join " ", map {$_->form} $atree->get_descendants({ordered => 1});
        $tokenized_text .= $sent . "\n";
    }

    my $dir = File::Temp->newdir("/COMP.TMP/bart.tmpdir.XXXXX");
    print STDERR "TMP_DIR: $dir\n";
    my $command = "cd $dir;";
    my $cp = join ":", map {'/net/cluster/TMP/mnovak/tools/BART-2.0/' . $_} ("src", "dist/BART.jar", "libs2/*");
    $command .= " java -Xmx1024m -classpath \"$cp\" -Delkfed.rootDir='/net/cluster/TMP/mnovak/tools/BART-2.0' elkfed.webdemo.Demo";

    my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);
    
    print $write $tokenized_text;
    close( $write );

    my @xml_lines = <$read>;
    print join "\n", @xml_lines;
    close( $read );
    Treex::Tool::ProcessUtils::safewaitpid( $pid );

    my ($sents, $corefs) = _extract_info(\@xml_lines);
    my @atrees = map {$_->get_tree($self->language, "a", $self->selector)} $doc->get_bundles;
    my @all_nodes = map { [ $_->get_descendants({ordered => 1}) ] } @atrees;
    my @all_forms = map { [ map {$_->form} @$_ ] } @all_nodes;

    my $align = $self->_align_arrays($sents, \@all_forms);

    log_info Dumper($sents);
    log_info Dumper($corefs);
    log_info Dumper($align);

    for my $entity_id (keys %$corefs) {
        my $chain = $corefs->{$entity_id};
        #print "ENTITY_ID: $entity_id\n";
        my $ante = locate_mention_head(shift @$chain, $align, \@all_nodes);
        while (my $anaph = locate_mention_head(shift @$chain, $align, \@all_nodes)) {
            print STDERR "ANAPH: " . $anaph->t_lemma . " " . $anaph->id . "\n";
            print STDERR "ANTE: " . $ante->t_lemma . " " . $ante->id . "\n";
            if (defined $ante && defined $anaph && !$ante->is_root && !$anaph->is_root) {
                $anaph->add_coref_text_nodes($ante);
            }
            $ante = $anaph;
        }
    }
}

sub locate_mention_head {
    my ($mention, $align, $anodes) = @_;

    return if (!defined $mention);

    my ($start_s, $start_w, $end_s, $end_w) = @$mention;

    #print STDERR "MENTION: $start_s, $start_w, $end_s, $end_w\n";

    ($start_s, $start_w) = split /,/, $align->{"$start_s,$start_w"};
    ($end_s, $end_w) = split /,/, $align->{"$end_s,$end_w"};

    my $start_anode = $anodes->[$start_s][$start_w];
    print STDERR "START ANODE: $start_s $start_w " . $start_anode->form . "\n";
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

    return $node1 if ($node1 == $node2);

    my $ances = $node2;

    while (defined $ances && !$node1->is_descendant_of($ances)) {
        $ances = $ances->parent;
    }

    return undef if (!defined $ances);
    return $ances;
}

sub _prepare_raw_text {
    my ($self, $doc) = @_;
    
    my $tokenized_text = "";
    foreach my $bundle ($doc->get_bundles) {
        my $atree = $bundle->get_tree($self->language, "a", $self->selector);
        my $sent = join " ", map {$_->form} $atree->get_descendants({ordered => 1});
        $tokenized_text .= $sent . "\n";
    }
    return $tokenized_text;
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
            push @sent_tokens, $1;
        }
    }

    return (\@sents, \%corefs);
}

sub process_document {
    my ($self, $doc) = @_;
    $self->process_document_one_zone_at_time($doc);
    #$self->_apply_function_on_each_zone($doc, \&process_document_one_zone_at_time, $self, $doc);
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
