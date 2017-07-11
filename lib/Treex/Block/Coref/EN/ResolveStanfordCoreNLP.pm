package Treex::Block::Coref::EN::ResolveStanfordCoreNLP;
use Moose;
use utf8;
use Treex::Core::Common;
use Treex::Tool::ProcessUtils;
use Net::EmptyPort qw(empty_port);
use LWP::UserAgent;
use JSON;
use Data::Printer;
use Encode qw(encode);

extends 'Treex::Core::Block';
with 'Treex::Block::Coref::ResolveFromRawText';

#WARNING: You may find in troubles if this block is run on cluster in many
#jobs and some of them are scheduled to the same machine. It may lead to
#client-server communication problems and errors. So, make sure by checking
#the logfiles if there are no "Error in HTTP response" messages.
#Running it in 20 jobs worked fine for me.


has 'algorithm' => ( 
    is => 'ro',
    isa => 'Str',
    default => 'deterministic+mention',
    documentation => 'values: deterministic|deterministic+mention|statistical|neural',
);

has 'tmp_dir_prefix' => ( is => 'ro', isa => 'Str', default => sub { -d '/COMP.TMP' ? '/COMP.TMP' : '.' } );
has '_tmp_dir' => ( is => 'rw', isa => 'Maybe[File::Temp::Dir]' );
has '_read' => ( is => 'rw', isa => 'Maybe[FileHandle]');
has '_write' => ( is => 'rw', isa => 'Maybe[FileHandle]');
has '_pid' => ( is => 'rw', isa => 'Maybe[Int]');
has '_server_port' => ( is => 'rw', isa => 'Int' );

has '_request_url' => ( is => 'ro', isa => 'Str', lazy => 1, builder => '_build_request_url' );

my $STANFORD_CMD = <<'CMD';
_term() { 
    #ps -o pid,comm,start --ppid $$ >&2;
    #strace -fe kill pkill -TERM -P $$ >&2;
    pkill -TERM -P $$ >&2
    wait
}
trap _term EXIT

cd /net/cluster/TMP/mnovak/tools/StanfordCoreNLP/stanford-corenlp-full-2016-10-31;
java -mx6g -cp "*" edu.stanford.nlp.pipeline.StanfordCoreNLPServer -port %d -timeout 2400000
CMD

my $STANFORD_SERVER_URL = 'http://localhost:%d/?properties={"annotators":"tokenize,ssplit,pos,lemma,ner,parse,%s",%s"tokenize.whitespace":"true", "ssplit.eolonly":"true","outputFormat":"json"}';

sub process_start {
    my ($self) = @_;
    $self->_init_stanford;
}

sub _build_request_url {
    my ($self) = @_;
    
    my %params = (
        'deterministic' => ['dcoref', ''],
        'deterministic+mention' => ['mention,dcoref', ''],
        'statistical' => ['mention,coref', '"coref.algorithm":"statistical",'],
        'neural' => ['mention,coref', '"coref.algorithm":"neural",'],
    );

    my @algparams = @{$params{$self->algorithm}};
    p @algparams;

    my $url = sprintf $STANFORD_SERVER_URL, $self->_server_port, @{$params{$self->algorithm}};
    return $url;
}

sub process_end {
    my ($self) = @_;
    $self->_finish_stanford;
}

sub _init_stanford {
    my ($self) = @_;
    
    log_info "Starting StanfordCoreNLP Server...";
    
    my $dir = File::Temp->newdir($self->tmp_dir_prefix . "/stanford.tmpdir.XXXXX");
    log_info "StanfordCoreNLP temporary directory: $dir";
    $self->_set_tmp_dir($dir);

    # find a free port
    my $port = empty_port();
    $self->_set_server_port($port);

    my $cmd = sprintf $STANFORD_CMD, $port;
    
    open SCRIPT, ">:utf8", "$dir/run.sh";
    print SCRIPT $cmd;
    close SCRIPT;
    
    #log_info "Launching BART 2.0: $command";
    my ( $read, $write, $pid );
    eval {
        ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe(["bash", "$dir/run.sh"]);
    };
    if ($@) {
        log_fatal $@;
    }
    
    #while (my $line = <$read>) {
    #    chomp $line;
    #    log_info $line;
    #    last if ($line =~ /StanfordCoreNLPServer listening/);
    #}
    log_info "StanfordCoreNLP Server started...";
    $self->_set_read($read);
    $self->_set_write($write);
    $self->_set_pid($pid);
}


sub _prepare_raw_text {
    my ($self, $bundles) = @_;
    return join "\n", map {
            my $atree = $_->get_tree($self->language, 'a', $self->selector);
            # remove whitespace inside the token
            join " ", map {my $form = $_->form; $form =~ s/\s//g; $form } $atree->get_descendants({ordered => 1});
        } @$bundles;
}

sub post_request {
    my ($self, $text) = @_;

    # build URL using port and specified parameters

    $text = encode('utf8', $text);
    my $req = HTTP::Request->new(POST => $self->_request_url);
    $req->content($text);
    
    my $ua = LWP::UserAgent->new();
    my $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        return decode_json $message;
    }
    else {
        log_warn "Error in HTTP response: ".$resp->status_line;
    }
    return;
}

sub _process_bundle_block {
    my ($self, $block_id, $bundles) = @_;

    log_info "Processing bundle block $block_id ...";

    my $raw_text = $self->_prepare_raw_text($bundles);
    #print STDERR $raw_text."\n";

    my $tries = 0;
    my $stanford_coref = $self->post_request($raw_text);
    # try restarting the server at most 3 times
    while (!defined $stanford_coref && $tries < 3) {
        $self->_finish_stanford;
        $self->_init_stanford;
        $stanford_coref = $self->post_request($raw_text);
        $tries++;
    }
    if (defined $stanford_coref) {
        $self->extract_stanford_coref_and_mark($stanford_coref, $bundles);
    }
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

    #p $stanford_data;

    my @atrees = map {$_->get_tree($self->language, 'a', $self->selector)} @$bundles;
    my @our_anodes = map {[$_->get_descendants({ordered=>1})]} @atrees;
    #my $sents = join "\n", map { my $sent = $_; join " ", map {$_->ord . ":" . $_->form} @$sent } @our_anodes;
    #print STDERR $sents."\n";

    #my $debug = 0;

    #print STDERR (join " ", map {scalar(@{$stanford_data->{corefs}->{$_}})} keys %{$stanford_data->{corefs}});
    #print STDERR "\n";


    # create a list of entities and their mentions as a list of lists of mentions' head tnodes
    my @entities = ();
    foreach my $entity_id (keys %{$stanford_data->{corefs}}) {
        #if ($entity_id == 93) {
        #    $debug = 1;
        #}
        #else {
        #    $debug = 0;
        #}
        my $stanford_entity = $stanford_data->{corefs}->{$entity_id};
        my $entity = [];
        foreach my $mention (@$stanford_entity) {
            # stanford mentions are indexed from 1
            my $anode = $our_anodes[$mention->{sentNum}-1][$mention->{headIndex}-1];
            #if ($debug) {
            #    printf STDERR "MENTION TEXT (%d, %d): %s\t ANODE FORM: %s\n", $mention->{sentNum}-1, $mention->{headIndex}-1, $mention->{text}, $anode->form;
            #}
            my ($tnode) = ($anode->get_referencing_nodes('a/lex.rf'), $anode->get_referencing_nodes('a/aux.rf'));
            #print STDERR "TNODE_ID: ".$tnode->id."\n";
            push @$entity, $tnode;
        }
        push @entities, $entity;
    }

    #print STDERR (join " ", map {scalar(@$_)} @entities);
    #print STDERR "\n";

    foreach my $entity (@entities) {
        my $ante = undef;
        foreach my $anaph (@$entity) {
            if (defined $ante && defined $anaph && ($anaph != $ante)) {
                print STDERR "ADDING COREF: " . $anaph->t_lemma . ' -> ' . $ante->t_lemma . "( " .$anaph->id . " -> " . $ante->id . " )\n";
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
This runs a Stanford Core NLP system as a server and sends it requests.
The input to the Stanford tool is sent tokenized and with sentences
splitted. Therefore, this block prevents the Stanford system from running
these two processing modules.
WARNING: You may find in troubles if this block is run on cluster in many
jobs and several of them are scheduled to the same machine. It may lead to
client-server communication problems and errors. So, make sure by checking
the logfiles if there are no "Error in HTTP response" messages.
Running it in 20 jobs worked fine for me.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
