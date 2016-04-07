package Treex::Block::Coref::SimpleEval;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Align::Utils;

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.tsv' );

sub process_tnode {
    my ($self, $tnode) = @_;

    return if !$tnode->wild->{in_coref_category};

    my ($src_anaph) = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [{ type => 'monolingual' }]);
    if (!defined $src_anaph) {
        log_warn "Undefined monolingual alignmnet from: " . $tnode->get_address;
        return;
    }

    my @src_antes = $src_anaph->get_coref_chain();
    my @src_ref_antes = Treex::Tool::Align::Utils::aligned_transitively(\@src_antes, [{ type => 'monolingual' }]);

    my @ref_antes = $tnode->get_coref_nodes();
    my %ref_antes_hash = map {$_->id => 1} @ref_antes;

    my @matched = grep {$ref_antes_hash{$_->id}} @src_ref_antes;

    print {$self->_file_handle} (@matched ? 1 : 0);
    print {$self->_file_handle} "\t";
    print {$self->_file_handle} (@src_ref_antes ? 1 : 0);
    print {$self->_file_handle} "\t";
    print {$self->_file_handle} (@ref_antes ? 1 : 0);
    print {$self->_file_handle} "\n";
}

# TODO: consider refactoring to produce the VW result format, which can be consequently processed by the MLyn eval scripts
# see Align::T::Eval for more

1;

=over

=item Treex::Block::Coref::SimpleEval

Precision, recall and F-measure for coreference.

USAGE:

cd ~/projects/czeng_coref
treex -L cs 
    Read::Treex from=@data/cs/analysed/pdt/eval/0001/list 
    Util::SetGlobal selector=src 
    Coref::RemoveLinks type=all 
    A2T::CS::MarkRelClauseHeads 
    A2T::CS::MarkRelClauseCoref 
    Util::SetGlobal selector=ref 
    Coref::PrepareSpecializedEval category=relpron 
    Coref::SimpleEval
| ./eval.pl

=back

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
