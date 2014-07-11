package Treex::Block::Write::AmrAligned;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.amr' );

has '+language' => (
    isa        => 'Maybe[Str]'
);

has '+selector' => (
    isa        => 'Maybe[Str]'
);

sub process_ttree {
    my ( $self, $ttree ) = @_;
    my ($src_ttree) = $ttree->src_tnode();
    my ($atree) = $src_ttree->get_zone()->get_atree;
   
    print  { $self->_file_handle } "# ::snt " . $ttree->get_zone()->sentence . "\n";
    print  { $self->_file_handle } "# ::tok ";#Jedina vec , ktera mne prekvapuje , je , jak rychle to postupuje .\n";
    print  { $self->_file_handle } join(' ', map{$_->form} $atree->get_descendants({ordered=>1})) . "\n";
    
    my %spans2nodes;
    my $child_no = 0;
    foreach my $ttop ($ttree->get_children({ordered=>1})){
        $self->_add_aligned_spans(\%spans2nodes, $ttop, $child_no);
        $child_no++;
    }
    print { $self->_file_handle } "# ::alignments " . join(' ', map { $_ . '|' . $spans2nodes{$_} } keys %spans2nodes );
    print  { $self->_file_handle } " ::annotator FakeAnnotator ::date 2013-09-26T04:27:51.715 ::editor AlignerTool v.03\n";
    
    foreach my $ttop ($ttree->get_children({ordered=>1})){ 
        print { $self->_file_handle } '(' . $ttop->t_lemma;
        foreach my $child ($ttop->get_children({ordered=>1})){
            $self->_process_tnode($child, '    ');
        }
        print { $self->_file_handle } ")\n";
    }
    die('AAAA');
}

sub _add_aligned_spans {
    
    my ($self, $tgt_hash, $tnode, $node_id) = @_;
    # process this node
    my $src_tnode = $tnode->src_tnode();
    my $lex_anode = $src_tnode ? $src_tnode->get_lex_anode() : undef;
   
    # just nodes that have a source t-node and a lexical a-node 
    if ($src_tnode and $lex_anode){
        # add this amr node under the a-node's ord into the hash
        my $ali_key = $lex_anode->ord . '-' . ($lex_anode->ord + 1);
        my $cur_alignment = ($tgt_hash->{$ali_key} // '');
        $cur_alignment .= '+' if ($cur_alignment);
        $cur_alignment .= $node_id;
        $tgt_hash->{$ali_key} = $cur_alignment;
    }

    # recurse to children
    my $child_no = 0;
    foreach my $tchild ($tnode->get_children({ordered=>1})){
        $self->_add_aligned_spans($tgt_hash, $tchild, $node_id . '.' . $child_no);
        $child_no++;
    }
    return;
}

sub _process_tnode {
    my ( $self, $tnode, $indent ) = @_;
    my $lemma = $tnode->get_attr('t_lemma');
    $lemma =~ s/\// \/ /;
    if ($lemma) {
      print { $self->_file_handle } "\n" . $indent;
      my $modifier = $tnode->wild->{'modifier'} ? $tnode->wild->{'modifier'} : $tnode->functor;
      if ($modifier && $modifier ne "root" && $indent ne "") {
         print { $self->_file_handle } ':' . $modifier;
      }
      print { $self->_file_handle } " ("  . $lemma;
    }
    foreach my $child ($tnode->get_children({ordered=>1})){
        $self->_process_tnode($child, $indent . '    ');
    }
    print { $self->_file_handle } ")";
}


1;

__END__

=head1 NAME

Treex::Block::Write::Amr

=head1 DESCRIPTION

Document writer for amr-like format.

=head1 ATTRIBUTES

=over

=item language

Language of tree


=item selector

Selector of tree


=back

=head1 METHODS

=over

=back

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
