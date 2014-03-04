package Treex::Block::Write::PDT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+compress' => (default=>1);

has 'vallex_filename' => ( isa => 'Str', is => 'rw', default => 'vallex.xml' );

sub _build_to {return '.';} # BaseTextWriter defaults to STDOUT

my ($w_fh, $m_fh, $a_fh, $t_fh);
my ($w_fn, $m_fn, $a_fn, $t_fn);

sub process_document{
    my ($self, $doc) = @_;
    $self->{extension} = '.w';
    $w_fn = $self->_get_filename($doc);
    $w_fh = $self->_open_file_handle($w_fn);
    my $print_fn = $w_fn;
    $print_fn =~ s/.w(.gz|)$/.[wamt]$1/;
    log_info "Saving to $print_fn";

    $self->{extension} = '.m';
    $m_fn = $self->_get_filename($doc);
    $m_fh = $self->_open_file_handle($m_fn);
    
    $self->{extension} = '.a';
    $a_fn = $self->_get_filename($doc);
    $a_fh = $self->_open_file_handle($a_fn);
    
    $self->{extension} = '.t';
    $t_fn = $self->_get_filename($doc);
    $t_fh = $self->_open_file_handle($t_fn);
    
    my $doc_id = $doc->file_stem . $doc->file_number;
    my $lang   = $self->language;
    my $vallex_name = $self->vallex_filename;
    print {$w_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<wdata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head><schema href="wdata_schema.xml"/></head>
<meta><original_format>treex</original_format></meta>
<doc id="$doc_id">
<docmeta/>
<para>
END
    print {$m_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<mdata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head>
  <schema href="mdata_schema.xml" />
  <references>
    <reffile id="w" name="wdata" href="$w_fn" />
  </references>
</head>
<meta><lang>$lang</lang></meta>
END
    print {$a_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<adata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head>
  <schema href="adata_schema.xml" />
  <references>
   <reffile id="m" name="mdata" href="$m_fn" />
   <reffile id="w" name="wdata" href="$w_fn" />
  </references>
</head>
<trees>
END
    print {$t_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<tdata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head>
  <schema href="tdata_schema.xml" />
  <references>
   <reffile id="a" name="adata" href="$a_fn" />
   <reffile id="v" name="vallex" href="$vallex_name" />
  </references>
</head>
<trees>
END

    $self->Treex::Core::Block::process_document($doc);
    
    print {$w_fh} "</para>\n</doc>\n</wdata>";
    print {$m_fh} "</mdata>";
    print {$a_fh} "</trees>\n</adata>";
    print {$t_fh} "</trees>\n</tdata>";
    foreach my $fh ($w_fh,$m_fh,$a_fh,$t_fh) {close $fh;}
    return;
}

sub escape_xml {
    my ($self, $string) = @_;
    return if !defined $string;
    $string =~ s/&/&amp;/;
    $string =~ s/</&lt;/;
    $string =~ s/>/&gt;/;
    $string =~ s/'/&apos;/;
    $string =~ s/"/&quot;/;
    return $string;
}

sub process_atree {
    my ($self, $atree) = @_;
    my $s_id = $atree->id;
    print {$m_fh} "<s id='m-$s_id'>\n";
    foreach my $anode ($atree->get_descendants({ordered=>1})){
        my ($id, $form, $lemma, $tag) = map{$self->escape_xml($_)} $anode->get_attrs(qw(id form lemma tag), {undefs=>'?'});
        my $nsa = $anode->no_space_after ? '<no_space_after>1</no_space_after>' : '';
        print {$w_fh} "<w id='w-$id'><token>$form</token>$nsa</w>\n";
        print {$m_fh} "<m id='m-$id'><w.rf>w#w-$id</w.rf><form>$form</form><lemma>$lemma</lemma><tag>$tag</tag></m>\n";
    }
    print {$m_fh} "</s>\n";
    print {$a_fh} "<LM id='a-$s_id'><s.rf>m#m-$s_id</s.rf><ord>0</ord>\n<children>\n";
    foreach my $child ($atree->get_children()) { $self->print_asubtree($child); }
    print {$a_fh} "</children>\n</LM>\n";
    return;
}

sub print_asubtree {
    my ($self, $anode) = @_;
    my ($id, $afun, $ord) = $anode->get_attrs(qw(id afun ord), {undefs=>'?'});
    print {$a_fh} "<LM id='a-$id'><m.rf>m#m-$id</m.rf><afun>$afun</afun><ord>$ord</ord>";
    print {$a_fh} '<is_member>1</is_member>' if $anode->is_member;
    print {$a_fh} '<is_parenthesis_root>1</is_parenthesis_root>' if $anode->is_parenthesis_root;
    if (my @children = $anode->get_children()){
        print {$a_fh} "\n<children>\n";
        foreach my $child (@children) { $self->print_asubtree($child); }
        print {$a_fh} "</children>\n";
    }
    print {$a_fh} "</LM>\n";
    return;
}

sub process_ttree {
    my ($self, $ttree) = @_;
    my $s_id = $ttree->id;
    my $a_s_id = $ttree->get_attr('atree.rf');
    if (!$a_s_id){
        $a_s_id = $s_id;
        $a_s_id =~ s/t_tree/a_tree/;
    }
    print {$t_fh} "<LM id='t-$s_id'><atree.rf>a#a-$a_s_id</atree.rf><nodetype>root</nodetype><deepord>0</deepord>\n<children>\n";
    foreach my $child ($ttree->get_children()) { $self->print_tsubtree($child); }
    print {$t_fh} "</children>\n</LM>\n";
    return;
}

sub print_tsubtree {
    my ($self, $tnode) = @_;
    my ($id, $ord) = $tnode->get_attrs(qw(id ord), {undefs=>'?'});
    print {$t_fh} "<LM id='t-$id'><deepord>$ord</deepord>";
    
    # boolean attrs
    foreach my $attr (qw(is_dsp_root is_generated is_member is_name_of_person is_parenthesis is_state)){
        print {$t_fh} "<$attr>1</$attr>" if $tnode->get_attr($attr);
    }
    
    # simple attrs
    foreach my $attr (qw(coref_special functor nodetype sentmod subfunctor t_lemma tfa val_frame.rf compl.rf coref_gram.rf coref_text.rf)){
        my $val = $self->escape_xml($tnode->get_attr($attr));
        print {$t_fh} "<$attr>$val</$attr>" if defined $val;
    }
    
    # grammatemes
    print {$t_fh} "<gram>";
    foreach my $attr (qw(sempos gender number degcmp verbmod deontmod tense aspect resultative dispmod iterativeness indeftype person number politeness negation)){ # definiteness diathesis
        my $val = $tnode->get_attr("gram/$attr");
        $val = 'n.denot' if !defined $val && $attr eq 'sempos'; #TODO sempos is required in PDT
        print {$t_fh} "<$attr>$val</$attr>" if defined $val;
    }
    print {$t_fh} "</gram>\n";
    
    # references
    my $lex = $tnode->get_lex_anode();
    my @aux = $tnode->get_aux_anodes();
    if ($lex || @aux){
        print {$t_fh} "<a>";
        printf {$t_fh} "<lex.rf>a#a-%s</lex.rf>", $lex->id if $lex;
        if (@aux==1){
            printf {$t_fh} "<aux.rf>a#a-%s</aux.rf>", $aux[0]->id;
        }
        if (@aux>1){
            print {$t_fh} "<aux.rf>";
            printf {$t_fh} "<LM>a#a-%s</LM>", $_->id for @aux;
            print {$t_fh} "</aux.rf>";
        }
        print {$t_fh} "</a>\n";
    }
    
    
    # recursive children
    if (my @children = $tnode->get_children()){
        print {$t_fh} "\n<children>\n";
        foreach my $child (@children) { $self->print_tsubtree($child); }
        print {$t_fh} "</children>\n";
    }
    print {$t_fh} "</LM>\n";
    return;
}

1;

__END__        

=encoding utf-8

=head1 NAME 

Treex::Block::Write::PDT - save *.w,*.m,*.a,*.t files

=head1 SYNOPSIS
 
 # convert *.treex files to *.w.gz,*.m.gz,*.a.gz,*.t.gz
 treex Write::PDT -- *.treex
 
 # convert *.treex.gz files to *.w,*.m,*.a,*.t
 treex Write::PDT compress=0 -- *.treex.gz

=head1 DESCRIPTION

Save Treex documents in PDT style PML files.

=head1 TODO

You can try reimplement this using Treex::PML if you dare.

compl.rf coref_gram.rf coref_text.rf may contain more links (<list ordered="0"><cdata format="PMLREF"/></list>)

is_member should be moved from AuxC/AuxP down (Treex vs. PDT style).

add t-layer attribute "quot"

Check links to Vallex (val_frame.rf)

Optional XML pretty printing (e.g. via xmllint --format), but anyone can do this when needed.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
