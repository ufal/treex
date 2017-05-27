package Treex::Block::Coref::EN::ResolveStanfordCoreNLP;
use Moose;
use utf8;
use Treex::Core::Common;
use Treex::Tool::ProcessUtils;
use LWP::UserAgent;
use JSON;
use Data::Printer;

extends 'Treex::Core::Block';
with 'Treex::Block::Coref::ResolveFromRawText';

has 'tmp_dir_prefix' => ( is => 'ro', isa => 'Str', default => sub { -d '/COMP.TMP' ? '/COMP.TMP' : '.' } );
has '_tmp_dir' => ( is => 'rw', isa => 'Maybe[File::Temp::Dir]' );
has '_read' => ( is => 'rw', isa => 'Maybe[FileHandle]');
has '_write' => ( is => 'rw', isa => 'Maybe[FileHandle]');
has '_pid' => ( is => 'rw', isa => 'Maybe[Int]');

my $STANFORD_CMD = <<'CMD';
_term() { 
    #ps -o pid,comm,start --ppid $$ >&2;
    #strace -fe kill pkill -TERM -P $$ >&2;
    pkill -TERM -P $$ >&2
    wait
}
trap _term EXIT

cd /net/cluster/TMP/mnovak/tools/StanfordCoreNLP/stanford-corenlp-full-2016-10-31;
java -mx6g -cp "*" edu.stanford.nlp.pipeline.StanfordCoreNLPServer -port 9000 -timeout 15000 2>&1
CMD

my $STANFORD_SERVER_URL = 'http://localhost:9000/?properties={"annotators":"tokenize,ssplit,pos,lemma,ner,parse,dcoref","tokenize.whitespace":"true", "ssplit.eolonly":"true","outputFormat":"json"}';

sub BUILD {
    my ($self) = @_;
    $self->_init_stanford;
}

sub DESTROY {
    my ($self) = @_;
    $self->_finish_stanford;
}

sub _init_stanford {
    my ($self) = @_;
    
    log_info "Starting StanfordCoreNLP Server...";
    
    my $dir = File::Temp->newdir($self->tmp_dir_prefix . "/stanford.tmpdir.XXXXX");
    log_info "StanfordCoreNLP temporary directory: $dir";
    $self->_set_tmp_dir($dir);
    
    open SCRIPT, ">:utf8", "$dir/run.sh";
    print SCRIPT $STANFORD_CMD;
    close SCRIPT;
    
    #log_info "Launching BART 2.0: $command";
    my ( $read, $write, $pid );
    eval {
        ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe(["bash", "$dir/run.sh"]);
    };
    if ($@) {
        log_fatal $@;
    }
    
    while (my $line = <$read>) {
        chomp $line;
        log_info $line;
        last if ($line =~ /StanfordCoreNLPServer listening/);
    }
    log_info "StanfordCoreNLP Server started...";
    $self->_set_read($read);
    $self->_set_write($write);
    $self->_set_pid($pid);
}


sub _prepare_raw_text {
    my ($self, $bundles) = @_;
    return join "\n", map {
            my $atree = $_->get_tree($self->language, 'a', $self->selector);
            join " ", map {$_->form} $atree->get_descendants({ordered => 1});
        } @$bundles;
}

sub post_request {
    my ($self, $text) = @_;

    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new(POST => $STANFORD_SERVER_URL);
    $req->content($text);
    my $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        return decode_json $message;
    }
    return;
}

sub _process_bundle_block {
    my ($self, $block_id, $bundles) = @_;

    log_info "Processing bundle block $block_id ...";

    my $raw_text = $self->_prepare_raw_text($bundles);

    log_info "$raw_text";

    my $stanford_coref = $self->post_request($raw_text);
    $self->extract_stanford_coref_and_mark($stanford_coref, $bundles);
}

sub _finish_stanford {
    my ($self) = @_;
    log_info "Ending StanfordCoreNLP Server...";
    close( $self->_write );
    close( $self->_read );
    kill('HUP', $self->_pid);
    $self->_set_read(undef);
    $self->_set_write(undef);
    $self->_set_pid(undef);
    #$self->_set_tmp_dir(undef);
}

sub extract_stanford_coref_and_mark {
    my ($self, $stanford_data, $bundles) = @_;

    my @atrees = map {$_->get_tree($self->language, 'a', $self->selector)} @$bundles;
    my @our_anodes = map {[$_->get_descendants({ordered=>1})]} @atrees;

    # create a list of entities and their mentions as a list of lists of mentions' head tnodes
    my @entities = ();
    foreach my $entity_id (keys %{$stanford_data->{corefs}}) {
        my $stanford_entity = $stanford_data->{corefs}->{$entity_id};
        my @entity = ();
        foreach my $mention (@$stanford_entity) {
            # stanford mentions are indexed from 1
            my $anode = $our_anodes[$mention->{sentNum}-1][$mention->{headIndex}-1];
            my ($tnode) = ($anode->get_referencing_nodes('a/lex.rf'), $anode->get_referencing_nodes('a/aux.rf'));
            push @entity, $tnode;
        }
        push @entities, \@entity;
    }

    foreach my $entity (@entities) {
        my $ante = undef;
        foreach my $anaph (@$entity) {
            if (defined $ante && defined $anaph && ($anaph != $ante)) {
                print STDERR "ADDING COREF: " . $anaph->id . " -> " . $ante->id . "\n";
                print STDERR "ANAPH: " . $anaph->t_lemma . "\n";
                $anaph->add_coref_text_nodes($ante);
            }
            $ante = $anaph;
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Coref::EN::ResolveStanfordCoreNLP

=head1 DESCRIPTION

Coreference resolver for English wrapping Stanford CoreNLP resolver.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
