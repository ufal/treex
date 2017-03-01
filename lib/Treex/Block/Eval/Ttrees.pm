package Treex::Block::Eval::Ttrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has gold_selector => (is=>'ro', default=>'gold', documentation=>'Which zone contains the gold standard annotation?');
has align_type => (is=>'ro', default=>'.*', documentation=>'regex specifying the type of alignment links from the evaluated tree to the test tree;'
                  .' usefull only in the rare case when multiple types of alignment are present');
has functor_details => (is=>'ro', default=>0, isa=>'Bool', documentation=>'report detailed statistics on functors');

my (%correct, %auto, %gold, $sentences);

sub process_ttree {
    my ($self, $ttree) = @_;
    $sentences++;
    my $auto_zone = $ttree->get_zone();
    my $language = $auto_zone->language;
    my $gold_ttree = $ttree->get_bundle()->get_zone($language, $self->gold_selector)->get_ttree();
    my @gold_tnodes = $gold_ttree->get_descendants({ordered=>1});
    $gold{nodes} += @gold_tnodes;

    my @tnodes = $ttree->get_descendants({ordered=>1});
    $auto{nodes} += @tnodes;
    foreach my $tnode (@tnodes){
        $self->process_tnode($tnode, $language);
    }
    return;
}

sub process_tnode {
    my ($self, $auto_node, $language) = @_;
    my ($gold_node) = $auto_node->get_aligned_nodes_of_type($self->align_type, $language, $self->gold_selector);
    return if !$gold_node;
    $correct{aligned}++;
    my $auto_parent = $auto_node->get_parent();
    my $gold_parent = $gold_node->get_parent();
    my ($aligned_to_auto_parent) = $auto_parent->get_aligned_nodes_of_type($self->align_type, $language, $self->gold_selector);
    $correct{structure}++ if $aligned_to_auto_parent && $aligned_to_auto_parent==$gold_parent;
    $correct{functor}++ if $auto_node->functor eq $gold_node->functor;
    $correct{LAS}++ if $auto_node->functor eq $gold_node->functor && $aligned_to_auto_parent && $aligned_to_auto_parent==$gold_parent;
    $correct{t_lemma}++ if $auto_node->t_lemma eq $gold_node->t_lemma;
    if ($self->functor_details){
        $correct{'functor_'.$auto_node->functor}++ if $auto_node->functor eq $gold_node->functor;
        $auto{functor}{$auto_node->functor}++;
        $gold{functor}{$gold_node->functor}++;
    }
    return;
}

sub process_end {
    my ($self) = @_;
    say "#auto_nodes=$auto{nodes} #gold_nodes=$gold{nodes} sentences=$sentences";
    foreach my $type (qw(aligned structure functor LAS t_lemma)){
        my $ok   = $correct{$type};
        my $prec = $ok / $auto{nodes};
        my $rec  = $ok / $gold{nodes};
        my $f1   = 2*$prec*$rec / ($prec + $rec);
        printf '%10s precision=%.3f recall=%.3f f1=%.3f ', $type, $prec, $rec, $f1;
        if ($type eq 'aligned') {
            printf "(extra_nodes=%.1f%% missing_nodes=%.1f%%)\n", (1-$prec)*100, (1-$rec)*100;
        } else {
            my $aligned_acc = $ok / $correct{aligned};
            printf "aligned_acc=%.3f\n", $aligned_acc;
        }
    }
    if ($self->functor_details){
        say '======= functor details =======';
        my (%prec, %rec, %f1);
        foreach my $functor (keys %{$auto{functor}}){
            $prec{$functor} = ($correct{'functor_'.$functor}||0) / $auto{functor}{$functor};
            $f1{$functor} = 0;
        }
        foreach my $functor (keys %{$gold{functor}}){
            $rec{$functor} = ($correct{'functor_'.$functor}||0) / $gold{functor}{$functor};
            $f1{$functor} = 0;
        }
        my @functors = keys %f1;
        foreach my $functor (@functors){
            my $p = $prec{$functor} || 0;
            my $r = $rec{$functor} || 0;
            $f1{$functor} = 2*$p*$r / (($p + $r)||1);
        }
        foreach my $functor (sort {($gold{functor}{$b}||0) <=> ($gold{functor}{$a}||0)} @functors){
            last if !$gold{functor}{$functor};
            printf "%10s #gold=%5d precision=%.3f recall=%.3f f1=%.3f\n", $functor, $gold{functor}{$functor}, $prec{$functor}||0, $rec{$functor}||0, $f1{$functor};
        }
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::Eval::Ttrees - compare gold and automatic annotation

=head1 SYNOPSIS

 # auto.treex.gz contains automatic trees in zone la_auto
 # aligned to the gold trees in zone la_gold.
 $ treex -Lla -Sauto Eval::Ttrees functor_details=1 -- auto.treex.gz
  #auto_nodes=2809 #gold_nodes=3513 sentences=199
   aligned precision=0.979 recall=0.783 f1=0.870 (extra=2.1% missing=21.7%)
 structure precision=0.798 recall=0.638 f1=0.709 aligned_acc=0.815
   functor precision=0.662 recall=0.529 f1=0.588 aligned_acc=0.676
       LAS precision=0.567 recall=0.453 f1=0.504 aligned_acc=0.579
   t_lemma precision=0.903 recall=0.722 f1=0.802 aligned_acc=0.922
 ======= functor details =======
       PAT #gold=  558 precision=0.758 recall=0.769 f1=0.763
      RSTR #gold=  555 precision=0.676 recall=0.955 f1=0.792
       ACT #gold=  417 precision=0.831 recall=0.859 f1=0.844
 ...

=head1 DESCRIPTION

This block evaluates the quality of automatic annotation of tectogrammatical layer
compared the gold standard annotation.
The main problem is that the number of t-nodes may be different,
so the two t-trees (auto and gold) need to be node-aligned before applying this block.
Only the first aligned node is considered (but one can constrain the alignments with parameter C<align_type>).

Precision, recall and f1 of structure, functor and t_lemma
are reported according to Klimeš (2007).
LAS means that both structure (parent) and functor are correct.

In the SYNOPSIS example:
2.1% of the auto t-nodes are not aligned to any gold t-node (i.e. alignment precision=0.979).
21.7% of the gold t-trees are not aligned to any auto tree (i.e. alignment recall=0.870).
B<structure> means that the node has a "correct" parent, i.e. that the parent of the auto t-node in question
is aligned to the parent of the gold t-node which is aligned to the auto t-node.

The C<aligned_acc> means the accuracy for a given type of annotation (t_lemma, functor,...)
only among the (1-1) aligned t-nodes.
So this number should be always reported together with the precision and recall of the alignment
(or equivalently, with the percentage of B<extra> t-nodes in the auto tree
and percentage of the t-nodes in the gold tree which are B<missing> in the auto tree).

In functor_details (unlike in the statistics above), the precision and recall
is computed only within the aligned nodes.

=head1 SEE ALSO

Klimeš 2007
Transformation-Based Tectogrammatical Dependency Analysis of English, Section 2 and Figure 1.
https://link.springer.com/content/pdf/10.1007%2F978-3-540-74628-7_5.pdf
Available also via
https://www.google.com/books?id=XBWD7oKSpg8C&oi=fnd&pg=PA15&ots=PEf0bW1UZo&sig=6H2liJ75iIlivErhD1iXgQOWdSo


=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
