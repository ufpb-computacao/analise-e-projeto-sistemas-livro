require 'yaml' # STEP ONE, REQUIRE YAML!
ALUNOS_FILE = 'config/alunos.yaml'
ALUNOS = YAML::load(File.open(ALUNOS_FILE))
CAPITULOS = YAML::load(File.open('config/capitulos.yaml'))

#puts alunos

namespace "alunos" do
  multitask :syncall
  desc 'Copiar os arquivos atuais para os diretórios de build.'
  task :sync =>[:clean,:syncall]
  desc 'Extrai os arquivos de tag para os diretórios de build.'
  multitask :archive, [:tag]
  desc 'Extrai páginas para gerar um arquivo de capítulo'
  multitask :splitchapter, [:inicio,:fim,:capitulo]
  desc 'Salva as mensagens personalizadas para os alunos.'
  multitask :messages
  desc 'Compila os arquivos gerando os PDFs.'
  task :build, [:tag] => [:messages]
  desc 'Gera os arquivos de releases. Realizar o merge com arquivo de editora.'
  task :release => [:build]

  def aluno_build_dir aluno
    "#{@RELEASE_DIR}/#{aluno['filename']}"
  end
  def syncdir aluno
    fulano_build_dir = aluno_build_dir(aluno)
    directory fulano_build_dir
    synctask = "sync:#{aluno['filename']}"
    task synctask => [fulano_build_dir] do
      system "rsync -r --delete livro/ #{fulano_build_dir}/livro"
    end
    task :syncall => synctask
  end

  def extractdir aluno
    fulano_build_dir = aluno_build_dir(aluno)
    directory fulano_build_dir
    this_task = "archive:#{aluno['filename']}"
    task this_task, [:tag] => [fulano_build_dir] do |t, args|
      fail "The TAG is missing" unless args.tag 
      system "git archive --format=tar --prefix=#{fulano_build_dir}/ #{args.tag} | (tar xf -) "
    end
    task :archive => this_task
  end

  def message aluno
    fulano_build_dir = aluno_build_dir(aluno)
    directory fulano_build_dir
    aluno['capitulos'].each do |capkey, entry|
      entry.each do |entry_point, msg|
        entry_filename = CAPITULOS[capkey]['arquivo']+".#{entry_point}" 
        entry_filepath = "#{fulano_build_dir}/livro/#{entry_filename}"
        file entry_filepath => [fulano_build_dir,ALUNOS_FILE] do
          mensagem = %{
[quote, Professor Vitor]
____

#{msg}

____

}
          IO.write(entry_filepath, mensagem)
        end
        task :messages => entry_filepath
      end
    end
  end

  def split_chapter aluno
    fulano_build_dir = aluno_build_dir(aluno)
    livro_pdf = "#{fulano_build_dir}/livro/livro.pdf"
    this_task = "splitchapter:#{aluno['filename']}"
    task this_task, [:inicio,:fim,:capitulo] => [livro_pdf] do |t, args|
      fail "Faltando argumento: página inicial" unless args.inicio  
      fail "Faltando argumento: página final" unless args.fim 
      fail "Faltando argumento: nome do capítulo" unless args.capitulo 
      system "pdftk #{livro_pdf} cat #{args.inicio}-#{args.fim} output #{fulano_build_dir}/../#{args.capitulo}-#{aluno['filename']}.pdf"
    end
    task :splitchapter => this_task
    
  end  

  def builddir aluno
    fulano_build_dir = aluno_build_dir(aluno)
    livro_asc = "#{fulano_build_dir}/livro/livro.asc"
    file livro_asc
    this_task = "build:#{aluno['filename']}"
    task this_task, [:tag] => [fulano_build_dir, livro_asc] do |t, args|
      fail "The TAG is missing" unless args.tag 
      Dir.chdir(fulano_build_dir) do
        @A2X_COMMAND="-v -k -f pdf --icons -a docinfo1 -a edition=#{args.tag} -a lang=pt-BR -d book --dblatex-opts '-T computacao -P latex.babel.language=brazilian' --dblatex-opts '-P show.comments=0' -a livro-pdf "
        system "#{@A2X_BIN} #{@A2X_COMMAND} livro/livro.asc"
      end
    end
    task :build => this_task
  end
  

  ALUNOS.each do |a|
    syncdir (a)
    extractdir(a)
    builddir(a)
    message(a)
    split_chapter(a)
    
  end



end

