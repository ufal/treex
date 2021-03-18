package Treex::Block::Write::PEDT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+compress' => (default=>1);

has 'vallex_filename' => ( isa => 'Str', is => 'rw', default => 'engvallex.xml' );

has 'vallex_prefix' => ( isa => 'Str', is => 'rw', default => 'en-v' );

sub _build_to {return '.';} # BaseTextWriter defaults to STDOUT

my ($a_fh, $t_fh);
my ($a_fn, $t_fn);

sub process_document{
    my ($self, $doc) = @_;

    $self->{extension} = '.a';
    $a_fn = $self->_get_filename($doc);
    $a_fh = $self->_open_file_handle($a_fn);
    my $print_fn = $a_fn;
    $print_fn =~ s/.a(.gz|)$/.[at]$1/;
    log_info "Saving to $print_fn";
    # all [wamt] files are stored in the same directory - there should be no directory in relative paths
    $a_fn = $doc->file_stem . $self->_document_extension($doc);

    # TODO p-file

    $self->{extension} = '.t';
    $t_fn = $print_fn;
    $t_fn =~ s/.\[at\]/$self->{extension}/;
    $t_fh = $self->_open_file_handle($t_fn);

    my $doc_id = $doc->file_stem . $doc->file_number;
    my $lang   = $self->language;
    my $vallex_name = $self->vallex_filename;
    my $vallex_prefix = $self->vallex_prefix;
    print {$a_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<adata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head>
  <schema href="adata_eng_schema.xml" />
</head>
<trees>
END
    print {$t_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<tdata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head>
  <schema href="tdata_eng_schema.xml" />
  <references>
   <reffile id="a" name="adata" href="$a_fn" />
   <reffile id="$vallex_prefix" name="vallex" href="$vallex_name" />
  </references>
</head>
<trees>
END

    $self->Treex::Core::Block::process_document($doc);

    print {$a_fh} "</trees>\n</adata>";
    print {$t_fh} "</trees>\n</tdata>";
    foreach my $fh ($a_fh,$t_fh) {close $fh;}
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

# adjust an ID to be used on a particular layer
# if $ref_layer is specified, transform the ID from to be used on $ref_layer instead of $layer
# if $is_tree is defined, apply also the rules aimed at root ids
sub adjust_id_to_layer {
    my ($id, $layer, $ref_layer, $is_tree) = @_;
    return $id if (!defined $id);
    if ($id !~ /^(english)?$layer-/i) {
        $id = $layer."-".$id;
    }
    if (defined $ref_layer) {
        if ($id =~ /^(english)?($layer)-/i) {
            $ref_layer = lc($2) eq $2 ? lc($ref_layer) : uc($ref_layer);
            $id =~ s/^(english)?$layer-/$1$ref_layer-/i;
        }
        if ($is_tree) {
            $id =~ s/$layer\_tree/$ref_layer\_tree/;
        }
    }
    return $id;
}

sub process_atree {
    my ($self, $atree) = @_;
    my $s_id = adjust_id_to_layer($atree->id, "a");
    print {$a_fh} "<LM id='$s_id'><ord>0</ord>\n<children>\n";
    foreach my $child ($atree->get_children()) { $self->print_asubtree($child); }
    print {$a_fh} "</children>\n</LM>\n";
    return;
}

sub print_asubtree {
    my ($self, $anode) = @_;
    my ($a_id, $form, $lemma, $tag, $afun, $ord) = map{$self->escape_xml($_)} $anode->get_attrs(qw(id form lemma tag afun ord), {undefs=>'?'});
    $a_id = adjust_id_to_layer($a_id, "a");
    my $nsa = $anode->no_space_after() ? '<no_space_after>1</no_space_after>' : '';
    print {$a_fh} "<LM id='$a_id'>";
    print {$a_fh} "<m><form>$form</form><lemma>$lemma</lemma><tag>$tag</tag><w><token>$form</token>$nsa</w></m><afun>$afun</afun><ord>$ord</ord>";
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
    my $s_id = adjust_id_to_layer($ttree->id, "t");
    my $a_s_id = adjust_id_to_layer($ttree->get_attr('atree.rf'), "a") // adjust_id_to_layer($s_id, "t", "a", 1);
    print {$t_fh} "<LM id='$s_id'><atree.rf>a#$a_s_id</atree.rf><nodetype>root</nodetype><deepord>0</deepord>\n<children>\n";
    foreach my $child ($ttree->get_children()) { $self->print_tsubtree($child); }
    print {$t_fh} "</children>\n</LM>\n";
    return;
}

sub print_tsubtree {
    my ($self, $tnode) = @_;
    my ($id, $ord) = $tnode->get_attrs(qw(id ord), {undefs=>'?'});
    $id = adjust_id_to_layer($id, "t");
    print {$t_fh} "<LM id='$id'><deepord>$ord</deepord>";

    # boolean attrs
    foreach my $attr (qw(is_dsp_root is_generated is_member is_name_of_person is_parenthesis is_state)){
        print {$t_fh} "<$attr>1</$attr>" if $tnode->get_attr($attr);
    }

    # simple attrs
    foreach my $attr (qw(coref_special functor nodetype sentmod subfunctor t_lemma tfa val_frame.rf)){
        my $val = $self->escape_xml($tnode->get_attr($attr));
        if ($attr eq 'val_frame.rf' and defined $val) {
            my $vallex_prefix = $self->vallex_prefix;
            $val =~ s/^[^#]+#/$vallex_prefix#/;
        }
        print {$t_fh} "<$attr>$val</$attr>" if defined $val;
    }

    # list attrs
    foreach my $attr (qw(compl.rf coref_gram.rf)){
        my @antes = $tnode->_get_node_list($attr);
        if (@antes) {
            print {$t_fh} "<$attr>";
            foreach my $ante (@antes) {
                my $ante_id = adjust_id_to_layer($ante->id, "t");
                print {$t_fh} "<LM>$ante_id</LM>";
            }
            print {$t_fh} "</$attr>";
        }
    }

    # coref text
    my @antes = $tnode->get_coref_text_nodes();
    if (@antes) {
        print {$t_fh} "<coref_text>";
        foreach my $ante (@antes) {
            my $ante_id = adjust_id_to_layer($ante->id, "t");
            print {$t_fh} "<LM><target-node.rf>$ante_id</target-node.rf><informal-type>SPEC</informal-type></LM>";
        }
        print {$t_fh} "</coref_text>";
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
        printf {$t_fh} "<lex.rf>a#%s</lex.rf>", adjust_id_to_layer($lex->id, "a") if $lex;
        if (@aux==1){
            printf {$t_fh} "<aux.rf>a#%s</aux.rf>", adjust_id_to_layer($aux[0]->id, "a");
        }
        if (@aux>1){
            print {$t_fh} "<aux.rf>";
            printf {$t_fh} "<LM>a#%s</LM>", adjust_id_to_layer($_->id, "a") for @aux;
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

Treex::Block::Write::PEDT - save *.a,*.t files

=head1 SYNOPSIS

 # convert *.treex files to *.a.gz,*.t.gz
 treex Write::PDT -- *.treex

 # convert *.treex.gz files to *.a,*.t
 treex Write::PDT compress=0 -- *.treex.gz

=head1 DESCRIPTION

Save Treex documents in PDT style PML files.

=head1 TODO

You can try reimplement this using Treex::PML if you dare.

is_member should be moved from AuxC/AuxP down (Treex vs. PDT style).

add t-layer attribute "quot"

Check links to Vallex (val_frame.rf)

Optional XML pretty printing (e.g. via xmllint --format), but anyone can do this when needed.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
