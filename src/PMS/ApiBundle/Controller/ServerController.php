<?php

namespace PMS\ApiBundle\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\Controller;

use PMS\ApiBundle\Entity\Server;
use PMS\ApiBundle\Entity\Account;

class ServerController extends BaseApiActionController
{

    public function actionList()
    {
        return array(
            'action' => array(
                'list',
                'ping',
                'add',
                'detail',
                'update',
            )
        );
    }

    public function listAction()
    {
        $list = array();
        $rep = $this->getDoctrine()->getRepository('PMSApiBundle:Server');
        $servers = $rep->findAll();
        foreach ($servers as $server)
        {
            $list[] = array(
                'host' => $server->getHost(),
            );
        }

        return $this->renderJson($list);
    }

    public function pingAction()
    {
        $rep = $this->getDoctrine()->getRepository('PMSApiBundle:Server');
        $server = $rep->findOneByHost($this->getRequest()->query->get('host', ''));

        $result = 0 < count($server);

        return $this->renderJson(array('result' => $result));
    }

    public function addAction()
    {
        $host = $this->getRequest()->request->get('host', null);

        if (is_null($host))
        {
            $param = array('host');

            return $this->renderErrorJson(400, array(
                'param' => $param,
            ));
        }

        $em = $this->getDoctrine()->getEntityManager();

        $registeredServers = $this->getDoctrine()->getRepository('PMSApiBundle:Server')->findBy(array('host' => $host));

        if (0 < count($registeredServers))
        {
            return $this->renderJson(array('result' => false));
        }

        $server = new Server();
        $server->setHost($host);
        $em->persist($server);
        $em->flush();

        return $this->renderJson(array('result' => true));
    }

    public function detailAction()
    {
        $host = $this->getRequest()->query->get('host', null);
        if (is_null($host))
        {
            return $this->renderErrorJson(400, array(
                'param' => array('host'),
            ));
        }
        $detail = array();
        $server = $this->getDoctrine()->getRepository('PMSApiBundle:Server')->findOneBy(array('host'=> $host));

        $result = array('domain' => array());
        if (!is_null($server))
        {
            foreach ($server->getSnss() as $sns)
            {
                if ('accepted' === $sns->getStatus())
                {
                    $result['domain'][] = $sns->getDomain();
                }
            }
        }

        return $this->renderJson($result);
    }

    public function updateAction()
    {
        $params = $this->getRequest()->request;

        $em = $this->getDoctrine()->getEntityManager();

        $domainsParam = $params->get('domain');
        if (is_null($domainsParam))
        {
            return $this->renderErrorJson(400, array(
                'param' => array('domain'),
            ));
        }
        $domains = json_decode($domainsParam);
        $sendTargets = array();
        foreach ($domains as $domain)
        {
            $sns = $this->getDoctrine()->getRepository('PMSApiBundle:Sns')->findOneBy(array('domain' => $domain));
            if (is_null($sns)) // TODO received domain will not install in PMS
            {
                continue;
            }

            if ('accepted' === $sns->getStatus()) // TODO not to use embedded string
            {
                $sendTargets[] = array(
                    'account' => $sns->getAccount(),
                    'sns' => $sns,
                    'passwords' => $this->getDoctrine()->getRepository('PMSApiBundle:SnsPasswords')->findOneBy(array('snsId' => $sns->getId())),
                );
                $sns->setStatus('running');
                $em->persist($sns);
            }
        }
        $em->flush();

        $mailer = $this->get('pms_api.mailer');
        foreach ($sendTargets as $target)
        {
            $mailer->sendInstallEmailMessage($target['account'], $target['sns'], $target['passwords']);
        }

        return $this->renderJson(array('result' => true));
    }

}
